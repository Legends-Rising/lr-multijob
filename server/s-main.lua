local VORPcore = exports.vorp_core:GetCore()

--------------------------------
-- DL-Society Integration
--------------------------------
local function isDLSocietyAvailable()
    return Config.UseDLSociety and GetResourceState('dl_society') == 'started'
end

local function getDLSocietyJobs()
    if not isDLSocietyAvailable() then return {} end
    
    -- Query all jobs from dl_jobs table
    local jobs = exports.oxmysql:executeSync([[
        SELECT j.name, j.label, g.grade, g.grade_label, g.salary 
        FROM dl_jobs j
        JOIN dl_job_grades g ON j.name = g.job_name
        ORDER BY j.name, g.grade
    ]])
    
    return jobs or {}
end

local function getDLJobGrades(jobName)
    if not isDLSocietyAvailable() then return {} end
    
    local grades = exports.oxmysql:executeSync([[
        SELECT grade, grade_label, salary, isBoss, armoryAccess, withDrawBalance
        FROM dl_job_grades
        WHERE job_name = ?
        ORDER BY grade
    ]], { jobName })
    
    return grades or {}
end

local function validateDLJob(jobName, grade)
    if not isDLSocietyAvailable() then return false, 0 end
    
    local jobGrade = exports.oxmysql:executeSync([[
        SELECT j.name, g.grade, g.salary
        FROM dl_jobs j
        JOIN dl_job_grades g ON j.name = g.job_name
        WHERE j.name = ? AND g.grade = ?
    ]], { jobName, grade })
    
    if jobGrade and jobGrade[1] then
        return true, tonumber(jobGrade[1].salary) or 0
    end
    
    return false, 0
end

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
RegisterServerEvent("vorp:setJob")
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

RegisterServerEvent("vorp:playerJobChange")
AddEventHandler("vorp:playerJobChange", function(source, newjob, oldjob)
    debugPrint('Player job changed:', source, newjob, oldjob)  
    TriggerClientEvent('lr-multijobs:client:openmenu', source)
end)

RegisterServerEvent("vorp:playerJobGradeChange")
AddEventHandler("vorp:playerJobGradeChange", function(source, newgrade, oldgrade)
    debugPrint('Player grade changed:', source, newgrade, oldgrade)
    TriggerClientEvent('lr-multijobs:client:openmenu', source)
end)

RegisterServerEvent('lr-multijobs:server:changeJob')
AddEventHandler('lr-multijobs:server:changeJob', function(job)
    local src = source
    local character = getCharacter(src)
    if not character then return end

    if character.job == job then
        VORPcore.NotifyTip(src, _U('sv_current_job_error'), 4000)
        return
    end

    local cid = character.charIdentifier
    
    -- Validate against society table only if that feature is enabled
    if Config.UseSocietyTable then
        local jobExists = exports.oxmysql:executeSync('SELECT DISTINCT job FROM society WHERE job = ?', { job })
        if not jobExists or not jobExists[1] then
            VORPcore.NotifyTip(src, _U('sv_invalid_job'), 4000)
            return
        end
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

RegisterServerEvent('lr-multijobs:server:deleteJob')
AddEventHandler('lr-multijobs:server:deleteJob', function(job)
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

RegisterServerEvent('lr-multijobs:server:newJob')
AddEventHandler('lr-multijobs:server:newJob', function(source, jobTable)
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

    -- Check job validity based on configured job system
    local isJobValid = false
    local jobSalary = 0
    
    -- If DL-Society is enabled and available, validate against it
    if Config.UseDLSociety and isDLSocietyAvailable() then
        isJobValid, jobSalary = validateDLJob(jobTable.name, jobTable.grade.level)
        if not isJobValid then
            debugPrint('Job or grade not found in dl_jobs/dl_job_grades tables:', jobTable.name, jobTable.grade.level)
            return
        end
        
        -- Use salary from DL-Society if none provided
        if not jobTable.salary then
            jobTable.salary = jobSalary
            debugPrint('Using salary from dl-society:', jobTable.salary)
        end
    -- Otherwise, if standard society table is enabled, check there
    elseif Config.UseSocietyTable then
        local jobExists = exports.oxmysql:executeSync('SELECT 1 FROM society WHERE job = ? AND jobgrade = ?', 
            { jobTable.name, jobTable.grade.level })
        if not jobExists or not jobExists[1] then
            debugPrint('Job or grade not found in society table:', jobTable.name, jobTable.grade.level)
            return
        end
        
        -- If using society table and no salary provided, try to get it from the society table
        if not jobTable.salary then
            local salaryData = exports.oxmysql:executeSync('SELECT salary FROM society WHERE job = ? AND jobgrade = ?', 
                { jobTable.name, jobTable.grade.level })
            if salaryData and salaryData[1] then
                jobTable.salary = salaryData[1].salary
                debugPrint('Using salary from society table:', jobTable.salary)
            end
        end
    else
        -- When neither job system is enabled, any job name is valid
        isJobValid = true
    end

    -- Use default salary if none provided or found
    if not jobTable.salary then
        jobTable.salary = Config.DefaultSalary
        debugPrint('Using default salary:', jobTable.salary)
    end

    -- Check job conflict if feature enabled
    if Config.EnableJobConflicts and Config.JobConflicts then
        local currentJobs = exports.oxmysql:executeSync('SELECT job FROM player_jobs WHERE citizenid = ?', { cid }) or {}
        for _, row in ipairs(currentJobs) do
            local existingJob = row.job
            local directConflicts = Config.JobConflicts[jobTable.name] or {}
            for _, forbidden in ipairs(directConflicts) do
                if forbidden == existingJob then
                    VORPcore.NotifyTip(src, ('You cannot take the %s job while you already have %s.'):format(jobTable.name, existingJob), 4000)
                    debugPrint('Job conflict detected (direct):', jobTable.name, 'vs', existingJob)
                    return
                end
            end
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

    -- Check if we need to update DB schema first
    local hasJobSalaryColumn = exports.oxmysql:executeSync("SHOW COLUMNS FROM player_jobs LIKE 'salary'")
    if not hasJobSalaryColumn[1] then
        debugPrint('Adding salary column to player_jobs table')
        exports.oxmysql:executeSync("ALTER TABLE player_jobs ADD COLUMN salary INT DEFAULT 0")
    end

    local success = pcall(function()
        exports.oxmysql:executeSync(
            'INSERT INTO player_jobs (citizenid, job, grade, salary) VALUES (?, ?, ?, ?) ON DUPLICATE KEY UPDATE grade = VALUES(grade), salary = VALUES(salary)',
            { cid, jobTable.name, jobTable.grade.level, jobTable.salary }
        )
    end)

    if not success then
        debugPrint('Failed to add/update job - possible database error')
        return
    end

    debugPrint('Job added/updated successfully with salary:', jobTable.salary)
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

    -- Skip Jobs config check - let the newJob event handle validation
    
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
    
    local result

    -- Priority: DL-Society > Standard Society > player_jobs only
    if Config.UseDLSociety and isDLSocietyAvailable() then
        -- Query with job details from dl_jobs and dl_job_grades
        result = exports.oxmysql:executeSync([[
            SELECT DISTINCT pj.job, pj.grade, pj.salary, j.label as jobLabel, g.grade_label as gradeLabel
            FROM player_jobs pj
            JOIN dl_jobs j ON pj.job = j.name
            JOIN dl_job_grades g ON pj.job = g.job_name AND pj.grade = g.grade
            WHERE pj.citizenid = ?
        ]], { cid })
        
        -- If no results from join, try getting from player_jobs only
        if not result or #result == 0 then
            debugPrint('No matching jobs in dl-society tables, falling back to player_jobs')
            result = exports.oxmysql:executeSync([[
                SELECT DISTINCT job, grade, salary
                FROM player_jobs
                WHERE citizenid = ?
            ]], { cid })
        end
    elseif Config.UseSocietyTable then
        -- Query with salary from society table
        result = exports.oxmysql:executeSync([[
            SELECT DISTINCT pj.job, pj.grade, s.salary
            FROM player_jobs pj
            JOIN society s ON pj.job = s.job AND pj.grade = s.jobgrade
            WHERE pj.citizenid = ?
        ]], { cid })
    else
        -- When no job system is enabled, only pull jobs from player_jobs table
        result = exports.oxmysql:executeSync([[
            SELECT DISTINCT job, grade, salary
            FROM player_jobs
            WHERE citizenid = ?
        ]], { cid })
    end
    
    debugPrint('Database result:', json.encode(result))
    
    if not result or #result == 0 then
        debugPrint('No jobs found in database')
        cb({})
        return
    end

    local storeJobs = {}
    for _, v in pairs(result) do
        debugPrint('Processing job:', v.job, 'grade:', v.grade)
        
        -- Calculate salary based on configuration
        local salary = v.salary or Config.DefaultSalary
        
        -- Create job label if not provided
        local jobLabel = v.jobLabel or v.job
        local gradeLabel = v.gradeLabel or ('Grade ' .. v.grade)
        
        table.insert(storeJobs, {
            job = v.job,
            salary = salary,
            jobLabel = jobLabel,
            gradeLabel = gradeLabel,
            grade = v.grade,
            isCurrent = (character.job == v.job)
        })
        debugPrint('Added job to menu:', v.job, 'with salary:', salary)
    end
    
    debugPrint('Total jobs found:', #storeJobs)
    cb(storeJobs)
end)

--------------------------------
-- Register Commands
--------------------------------
RegisterCommand("addJob", function(source, args, rawCommand)
    if #args < 3 then 
        VORPcore.NotifyTip(source, "Usage: /addJob [playerID] [jobName] [grade] [salary]", 4000)
        return 
    end
    
    local target_id = tonumber(args[1])
    local job = args[2]
    local grade = tonumber(args[3])
    local salary = tonumber(args[4]) or Config.DefaultSalary
    
    debugPrint('AddJob command:', target_id, job, grade, 'salary:', salary)
    
    -- Check if job exists in society table (only if that feature is enabled)
    if Config.UseSocietyTable then
        local jobExists = exports.oxmysql:executeSync('SELECT 1 FROM society WHERE job = ? AND jobgrade = ?', 
            { job, grade })
        if not jobExists or not jobExists[1] then
            debugPrint('Job or grade not found in society table:', job, grade)
            return
        end
    end
    
    local jobTable = {
        name = job,
        grade = {
            level = grade
        },
        salary = salary
    }
    
    TriggerEvent('lr-multijobs:server:newJob', target_id, jobTable)
end, false)

RegisterCommand('myjobs', function(source, args, rawCommand)
    TriggerClientEvent('lr-multijobs:client:openmenu', source)
end, false)

RegisterCommand('removejob', function(source, args, raw)
    local src = source
    if not args[1] or not args[2] then
        VORPcore.NotifyTip(src, "Usage: /removejob [playerID] [jobName]", 4000)
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
end, false)

-- Register command suggestions for clients at server start
Citizen.CreateThread(function()
    -- Wait for resource to fully start
    Wait(1000) 
    
    -- Register command suggestions for all players
    TriggerClientEvent('chat:addSuggestion', -1, '/addJob', 'Add a job to a player', {
        { name = 'playerID', help = 'Player server ID' },
        { name = 'jobName', help = 'Name of the job' },
        { name = 'grade', help = 'Job grade level' },
        { name = 'salary', help = 'Job salary (optional)' }
    })
    
    TriggerClientEvent('chat:addSuggestion', -1, '/myjobs', 'Open your jobs menu', {})
    
    TriggerClientEvent('chat:addSuggestion', -1, '/removejob', 'Remove a job from a player', {
        { name = 'playerID', help = 'Player server ID' },
        { name = 'jobName', help = 'Name of the job to remove' }
    })
    
    TriggerClientEvent('chat:addSuggestion', -1, '/listjobs', 'List all available jobs from society table (admin only)', {})
    
    TriggerClientEvent('chat:addSuggestion', -1, '/assignjob', 'Assign a job to a player (admin only)', {
        { name = 'playerID', help = 'Player server ID' },
        { name = 'jobName', help = 'Name of the job' },
        { name = 'grade', help = 'Job grade level' }
    })
    
    TriggerClientEvent('chat:addSuggestion', -1, '/jobsmenu', 'Open the admin job assignment menu (admin only)', {
        { name = 'playerID', help = 'Optional: Specific player ID to assign jobs to' }
    })
    
    debugPrint('Command suggestions registered')
end)

--------------------------------
-- Admin Job Assignment Commands
--------------------------------

-- Command to list all available jobs from society table (admin only)
RegisterCommand("listjobs", function(source, args, rawCommand)
    local src = source
    local character = getCharacter(src)
    if not character then return end
    
    -- Check if user is admin (you might need to adjust this based on your permission system)
    if character.group ~= "admin" then
        VORPcore.NotifyTip(src, "You don't have permission to use this command", 4000)
        return
    end
    
    local jobs
    
    -- Check which job system to use
    if Config.UseDLSociety and isDLSocietyAvailable() then
        -- Get jobs from dl-society
        debugPrint('Getting jobs from dl-society')
        jobs = getDLSocietyJobs()
        
        -- Format jobs to match expected structure
        for i, job in ipairs(jobs) do
            jobs[i].jobgrade = job.grade
            jobs[i].job = job.name
        end
    elseif Config.UseSocietyTable then
        -- Get jobs from standard society table
        debugPrint('Getting jobs from society table')
        jobs = exports.oxmysql:executeSync("SELECT DISTINCT job, jobgrade, salary FROM society ORDER BY job, jobgrade")
    else
        VORPcore.NotifyTip(src, "No job system is enabled in the configuration", 4000)
        return
    end
    
    if not jobs or #jobs == 0 then
        VORPcore.NotifyTip(src, "No jobs found", 4000)
        return
    end
    
    -- Send list to client for display
    TriggerClientEvent('lr-multijobs:client:showJobsList', src, jobs)
end, false)

-- Command to assign a job to a player (admin only)
RegisterCommand("assignjob", function(source, args, rawCommand)
    local src = source
    local character = getCharacter(src)
    if not character then return end
    
    -- Check if user is admin (adjust based on your permission system)
    if character.group ~= "admin" then
        VORPcore.NotifyTip(src, "You don't have permission to use this command", 4000)
        return
    end
    
    if #args < 3 then
        VORPcore.NotifyTip(src, "Usage: /assignjob [playerID] [jobName] [grade]", 4000)
        return
    end
    
    local target_id = tonumber(args[1])
    local job = args[2]
    local grade = tonumber(args[3])
    
    -- Check if target exists
    local targetChar = getCharacter(target_id)
    if not targetChar then
        VORPcore.NotifyTip(src, "Player not found", 4000)
        return
    end
    
    local isJobValid = false
    local salary = Config.DefaultSalary
    
    -- Check which job system to use for validation
    if Config.UseDLSociety and isDLSocietyAvailable() then
        -- Validate against dl-society
        isJobValid, salary = validateDLJob(job, grade)
        if not isJobValid then
            VORPcore.NotifyTip(src, "Job or grade not found in dl-society", 4000)
            return
        end
    elseif Config.UseSocietyTable then
        -- Validate against standard society table
        local jobExists = exports.oxmysql:executeSync('SELECT salary FROM society WHERE job = ? AND jobgrade = ?', 
            { job, grade })
        if not jobExists or not jobExists[1] then
            VORPcore.NotifyTip(src, "Job or grade not found in society table", 4000)
            return
        end
        salary = jobExists[1].salary
    else
        -- No job validation when neither system is enabled
        isJobValid = true
    end
    
    -- Create job table
    local jobTable = {
        name = job,
        grade = {
            level = grade
        },
        salary = salary
    }
    
    -- Add job to player
    TriggerEvent('lr-multijobs:server:newJob', target_id, jobTable)
    VORPcore.NotifyTip(src, "Job assigned to player", 4000)
end, false)

-- Command to open admin job assignment menu (admin only)
RegisterCommand("jobsmenu", function(source, args, rawCommand)
    local src = source
    local character = getCharacter(src)
    if not character then return end
    
    -- Check if user is admin
    if character.group ~= "admin" then
        VORPcore.NotifyTip(src, "You don't have permission to use this command", 4000)
        return
    end
    
    -- Check which job system is enabled
    if not (Config.UseDLSociety and isDLSocietyAvailable()) and not Config.UseSocietyTable then
        VORPcore.NotifyTip(src, "No job system is enabled in the configuration", 4000)
        return
    end
    
    -- If player ID is provided, open the job assignment menu for that player
    if args[1] then
        local target_id = tonumber(args[1])
        local targetChar = getCharacter(target_id)
        if not targetChar then
            VORPcore.NotifyTip(src, "Player not found", 4000)
            return
        end
        
        -- Get online players
        local onlinePlayers = {}
        onlinePlayers[#onlinePlayers + 1] = {
            id = target_id,
            name = GetPlayerName(target_id) or "Unknown",
            character = targetChar
        }
        
        -- Get all available jobs based on the active job system
        local jobs
        if Config.UseDLSociety and isDLSocietyAvailable() then
            jobs = getDLSocietyJobs()
            
            -- Format jobs to match expected structure
            for i, job in ipairs(jobs) do
                jobs[i].jobgrade = job.grade
                jobs[i].job = job.name
            end
        else
            jobs = exports.oxmysql:executeSync("SELECT DISTINCT job, jobgrade, salary FROM society ORDER BY job, jobgrade")
        end
        
        if not jobs or #jobs == 0 then
            VORPcore.NotifyTip(src, "No jobs found", 4000)
            return
        end
        
        -- Send to client for menu display
        TriggerClientEvent('lr-multijobs:client:openAdminMenu', src, onlinePlayers, jobs, target_id)
    else
        -- Get all online players
        local onlinePlayers = {}
        local players = GetPlayers()
        
        for _, playerId in ipairs(players) do
            local playerChar = getCharacter(playerId)
            if playerChar then
                onlinePlayers[#onlinePlayers + 1] = {
                    id = playerId,
                    name = GetPlayerName(playerId) or "Unknown"
                }
            end
        end
        
        -- Get all available jobs based on the active job system
        local jobs
        if Config.UseDLSociety and isDLSocietyAvailable() then
            jobs = getDLSocietyJobs()
            
            -- Format jobs to match expected structure
            for i, job in ipairs(jobs) do
                jobs[i].jobgrade = job.grade
                jobs[i].job = job.name
            end
        else
            jobs = exports.oxmysql:executeSync("SELECT DISTINCT job, jobgrade, salary FROM society ORDER BY job, jobgrade")
        end
        
        if not jobs or #jobs == 0 then
            VORPcore.NotifyTip(src, "No jobs found", 4000)
            return
        end
        
        -- Send to client for menu display
        TriggerClientEvent('lr-multijobs:client:openAdminMenu', src, onlinePlayers, jobs)
    end
end, false)

-- Server event to refresh jobs list
RegisterServerEvent('lr-multijobs:server:refreshJobsList')
AddEventHandler('lr-multijobs:server:refreshJobsList', function()
    local src = source
    local character = getCharacter(src)
    if not character then return end
    
    -- Check if user is admin
    if character.group ~= "admin" then
        VORPcore.NotifyTip(src, "You don't have permission to use this feature", 4000)
        return
    end
    
    -- Check which job system is enabled
    if not (Config.UseDLSociety and isDLSocietyAvailable()) and not Config.UseSocietyTable then
        VORPcore.NotifyTip(src, "No job system is enabled in the configuration", 4000)
        return
    end
    
    -- Get all available jobs based on the active job system
    local jobs
    if Config.UseDLSociety and isDLSocietyAvailable() then
        jobs = getDLSocietyJobs()
        
        -- Format jobs to match expected structure
        for i, job in ipairs(jobs) do
            jobs[i].jobgrade = job.grade
            jobs[i].job = job.name
        end
    else
        jobs = exports.oxmysql:executeSync("SELECT DISTINCT job, jobgrade, salary FROM society ORDER BY job, jobgrade")
    end
    
    if not jobs or #jobs == 0 then
        VORPcore.NotifyTip(src, "No jobs found", 4000)
        return
    end
    
    -- Send list to client for display
    TriggerClientEvent('lr-multijobs:client:showJobsList', src, jobs)
end)

-- Server event for admin job assignment
RegisterServerEvent('lr-multijobs:server:adminAssignJob')
AddEventHandler('lr-multijobs:server:adminAssignJob', function(targetId, job, grade, salary)
    local src = source
    local character = getCharacter(src)
    if not character then return end
    
    -- Check if user is admin
    if character.group ~= "admin" then
        VORPcore.NotifyTip(src, "You don't have permission to assign jobs", 4000)
        return
    end
    
    targetId = tonumber(targetId)
    grade = tonumber(grade)
    salary = tonumber(salary) or Config.DefaultSalary
    
    -- Check if target exists
    local targetChar = getCharacter(targetId)
    if not targetChar then
        VORPcore.NotifyTip(src, "Player not found", 4000)
        return
    end
    
    -- Create job table
    local jobTable = {
        name = job,
        grade = {
            level = grade
        },
        salary = salary
    }
    
    -- Add job to player
    TriggerEvent('lr-multijobs:server:newJob', targetId, jobTable)
    VORPcore.NotifyTip(src, "Job " .. job .. " (Grade " .. grade .. ") assigned to player ID: " .. targetId, 4000)
    VORPcore.NotifyTip(targetId, "You have been assigned the job: " .. job .. " (Grade " .. grade .. ")", 4000)
end)
