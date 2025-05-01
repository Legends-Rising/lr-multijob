local VORPcore = exports.vorp_core:GetCore()

--------------------------------
-- Functions
--------------------------------
local function getCharacter(source)
    local user = VORPcore.getUser(source)
    if not user then return nil end
    return user.getUsedCharacter
end

local function getPlayerMaxJobs(source)
    local character = getCharacter(source)
    if not character then return Config.DefaultMaxJobs end
    
    local group = character.group
    return Config.GroupMaxJobs[group] or Config.DefaultMaxJobs
end

local function debugPrint(...)
    if Config.Debug then
        print('[lr-MultiJobs]', ...)
    end
end

--------------------------------
-- Events
--------------------------------
AddEventHandler("vorp:setJob", function(source, job, grade)
    debugPrint('Job set detected:', source, job, grade)
    
    if job == 'unemployed' then return end
    
    local jobTable = {
        name = job,
        grade = {
            level = grade
        }
    }
    
    TriggerEvent('lr-multijobs:server:newJob', source, jobTable)
end)

RegisterServerEvent('vorp:setGroup')
AddEventHandler('vorp:setGroup', function(source, job, grade)
    debugPrint('Group set detected:', source, job, grade)
    
    if job == 'unemployed' then return end
    
    local jobTable = {
        name = job,
        grade = {
            level = grade
        }
    }
    
    TriggerEvent('lr-multijobs:server:newJob', source, jobTable)
end)

AddEventHandler("vorp:playerJobChange", function(source, newjob, oldjob)
    debugPrint('Player job changed:', source, newjob, oldjob)  
    TriggerClientEvent('lr-multijobs:client:openmenu', source)
end)

AddEventHandler("vorp:playerJobGradeChange", function(source, newgrade, oldgrade)
    debugPrint('Player grade changed:', source, newgrade, oldgrade)
    TriggerClientEvent('lr-multijobs:client:openmenu', source)
end)

RegisterNetEvent('lr-multijobs:server:changeJob', function(job)
    local src = source
    local character = getCharacter(src)
    if not character then return end

    if character.job == job then
        VORPcore.NotifyTip(src, _U('sv_current_job_error'), 4000)
        return
    end

    local cid = character.charIdentifier
    
    -- Check if job exists in society table
    local jobExists = exports.oxmysql:executeSync('SELECT DISTINCT job FROM society WHERE job = ?', { job })
    if not jobExists or not jobExists[1] then
        VORPcore.NotifyTip(src, _U('sv_invalid_job'), 4000)
        return
    end

    local result = exports.oxmysql:executeSync('SELECT * FROM player_jobs WHERE citizenid = ? AND job = ?', { cid, job })
    if not result or not result[1] then
        VORPcore.NotifyTip(src, _U('sv_invalid_job'), 4000)
        return
    end

    local grade = tonumber(result[1].grade) or 0

    character.setJob(job, false)
    character.setJobGrade(grade, false)

    VORPcore.NotifyTip(src, _U('sv_job') .. ': ' .. job, 4000)
end)

RegisterNetEvent('lr-multijobs:server:deleteJob', function(job)
    local src = source
    local character = getCharacter(src)
    if not character then return end

    local cid = character.charIdentifier

    exports.oxmysql:executeSync('DELETE FROM player_jobs WHERE citizenid = ? AND job = ?', { cid, job })

    VORPcore.NotifyTip(src, _U('sv_job_deleted') .. ' ' .. job .. ' ' .. _U('sv_job_deleted_2'), 4000)

    if character.job == job then
        character.setJob("unemployed", false)
        character.setJobGrade(0, false)
    end
end)

RegisterNetEvent('lr-multijobs:server:newJob', function(source, jobTable)
    local src = type(source) == "table" and source.source or source
    debugPrint('Adding job:', src, json.encode(jobTable))
    
    if type(src) == "string" then
        src = tonumber(src)
    end
    
    local character = getCharacter(src)
    if not character then 
        debugPrint('No character found for source:', src)
        return 
    end

    local cid = character.charIdentifier
    debugPrint('Character ID:', cid)
    
    if not jobTable or not jobTable.name then
        debugPrint('Invalid job table')
        return
    end

    if jobTable.name == 'unemployed' then
        debugPrint('Skipping unemployed job')
        return
    end

    -- Check if job exists in society table
    local jobExists = exports.oxmysql:executeSync('SELECT 1 FROM society WHERE job = ? AND jobgrade = ?', 
        { jobTable.name, jobTable.grade.level })
    if not jobExists or not jobExists[1] then
        debugPrint('Job or grade not found in society table:', jobTable.name, jobTable.grade.level)
        return
    end

    -- Check job conflict if feature enabled
    if Config.EnableJobConflicts and Config.JobConflicts then
        -- Get current jobs of the player (including the active one)
        local currentJobs = exports.oxmysql:executeSync('SELECT job FROM player_jobs WHERE citizenid = ?', { cid }) or {}
        for _, row in ipairs(currentJobs) do
            local existingJob = row.job
            -- Direct list: does the new job forbid the existing one?
            local directConflicts = Config.JobConflicts[jobTable.name] or {}
            for _, forbidden in ipairs(directConflicts) do
                if forbidden == existingJob then
                    VORPcore.NotifyTip(src, ('You cannot take the %s job while you already have %s.'):format(jobTable.name, existingJob), 4000)
                    debugPrint('Job conflict detected (direct):', jobTable.name, 'vs', existingJob)
                    return
                end
            end
            -- Reverse list: does the existing job forbid the new one?
            local reverseConflicts = Config.JobConflicts[existingJob] or {}
            for _, forbidden in ipairs(reverseConflicts) do
                if forbidden == jobTable.name then
                    VORPcore.NotifyTip(src, ('Your current job %s conflicts with %s.'):format(existingJob, jobTable.name), 4000)
                    debugPrint('Job conflict detected (reverse):', existingJob, 'vs', jobTable.name)
                    return
                end
            end
        end
    end

    local maxJobs = getPlayerMaxJobs(src)
    local countData = exports.oxmysql:executeSync('SELECT COUNT(*) as jobCount FROM player_jobs WHERE citizenid = ?', { cid })
    local jobCount = countData and countData[1] and countData[1].jobCount or 0

    local existingJob = exports.oxmysql:executeSync('SELECT 1 FROM player_jobs WHERE citizenid = ? AND job = ?', { cid, jobTable.name })
    if not existingJob[1] and jobCount >= maxJobs then
        debugPrint('Max jobs limit reached')
        VORPcore.NotifyTip(src, _U('sv_job_max'), 4000)
        return
    end

    local success = pcall(function()
        exports.oxmysql:executeSync(
            'INSERT INTO player_jobs (citizenid, job, grade) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE grade = VALUES(grade)',
            { cid, jobTable.name, jobTable.grade.level }
        )
    end)

    if not success then
        debugPrint('Failed to add/update job - possible database error')
        return
    end

    debugPrint('Job added/updated successfully')
    VORPcore.NotifyTip(src, "Job " .. jobTable.name .. " added to your jobs list", 4000)
end)

RegisterServerEvent("vorp_admin:addJob")
AddEventHandler("vorp_admin:addJob", function(target_id, job, grade, jobLabel)
    debugPrint('VORP addJob detected:', target_id, job, grade, jobLabel)
    
    if not target_id or not job or not grade then
        debugPrint('Invalid inputs:', target_id, job, grade)
        return
    end

    target_id = tonumber(target_id)
    grade = tonumber(grade)

    if not Config.Jobs[job] then
        debugPrint('Job not found in config:', job)
        return
    end

    -- Create job table format
    local jobTable = {
        name = job,
        grade = {
            level = grade
        }
    }
    
    TriggerEvent('lr-multijobs:server:newJob', target_id, jobTable)
end)

--------------------------------
-- Callbacks
--------------------------------
VORPcore.Callback.Register('lr-multijobs:server:getMyJobs', function(source, cb)
    local character = getCharacter(source)
    if not character then
        debugPrint('No character found')
        cb({})
        return
    end

    local cid = character.charIdentifier
    debugPrint('Getting jobs for character:', cid)
    
    -- Modified query to prevent duplicates by selecting distinct job records
    local result = exports.oxmysql:executeSync([[
        SELECT DISTINCT pj.job, pj.grade, s.salary
        FROM player_jobs pj
        JOIN society s ON pj.job = s.job AND pj.grade = s.jobgrade
        WHERE pj.citizenid = ?
    ]], { cid })
    
    debugPrint('Database result:', json.encode(result))
    
    if not result or #result == 0 then
        debugPrint('No jobs found in database')
        cb({})
        return
    end

    local storeJobs = {}
    for _, v in pairs(result) do
        debugPrint('Processing job:', v.job, 'grade:', v.grade)
        table.insert(storeJobs, {
            job = v.job,
            salary = v.salary or 0,
            jobLabel = v.job,
            gradeLabel = 'Grade ' .. v.grade,
            grade = v.grade,
            isCurrent = (character.job == v.job)
        })
        debugPrint('Added job to menu:', v.job)
    end
    
    debugPrint('Total jobs found:', #storeJobs)
    cb(storeJobs)
end)

--------------------------------
-- Register Commands
--------------------------------
RegisterCommand("addJob", function(source, args, rawCommand)
    if #args < 3 then 
        debugPrint('Invalid number of arguments')
        return 
    end
    
    local target_id = tonumber(args[1])
    local job = args[2]
    local grade = tonumber(args[3])
    
    debugPrint('AddJob command:', target_id, job, grade)
    
    -- Check if job exists in society table
    local jobExists = exports.oxmysql:executeSync('SELECT 1 FROM society WHERE job = ? AND jobgrade = ?', 
        { job, grade })
    if not jobExists or not jobExists[1] then
        debugPrint('Job or grade not found in society table:', job, grade)
        return
    end
    
    local jobTable = {
        name = job,
        grade = {
            level = grade
        }
    }
    
    TriggerEvent('lr-multijobs:server:newJob', target_id, jobTable)
end)

RegisterCommand('myjobs', function(source, args, rawCommand)
    TriggerClientEvent('lr-multijobs:client:openmenu', source)
end)

RegisterCommand('removejob', function(source, args, raw)
    local src = source
    if not args[1] or not args[2] then
        VORPcore.NotifyTip(src, _U('sv_provide') .. ' / ' .. _U('sv_provide_name'), 4000)
        return
    end

    local targetId = tonumber(args[1])
    local jobName  = tostring(args[2])
    local targetChar = getCharacter(targetId)
    if not targetChar then
        VORPcore.NotifyTip(src, _U('sv_not_online'), 4000)
        return
    end

    local cid = targetChar.charIdentifier
    local result = exports.oxmysql:executeSync('SELECT * FROM player_jobs WHERE citizenid = ? AND job = ?', { cid, jobName })
    if not result or not result[1] then
        VORPcore.NotifyTip(src, _U('sv_job_specified'), 4000)
        return
    end

    exports.oxmysql:executeSync('DELETE FROM player_jobs WHERE citizenid = ? AND job = ?', { cid, jobName })
    VORPcore.NotifyTip(src, ('Job: %s was removed from ID: %s'):format(jobName, targetId), 4000)

    if targetChar.job == jobName then
        targetChar.setJob('unemployed', false)
        targetChar.setJobGrade(0, false)
    end
end)
