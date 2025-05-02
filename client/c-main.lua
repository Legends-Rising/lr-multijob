--------------------------------
-- Initialization
--------------------------------
local VORPcore = exports.vorp_core:GetCore()
local Menu = exports.vorp_menu:GetMenuData()
local isMenuOpen = false

--------------------------------
-- Functions
--------------------------------
local function ShowMultiJob()
    local myJobs = VORPcore.Callback.TriggerAwait('lr-multijobs:server:getMyJobs')
    if not myJobs then
        VORPcore.NotifyRightTip(_U('cl_lang_3') .. ' - ' .. _U('sv_job_specified'), 4000)
        return
    end

    local MenuElements = {}

    for _, job in ipairs(myJobs) do
        local isDisabled = (job.isCurrent == true)

        local desc = (_U('cl_lang_grade') .. ': %s [%s]\n' .. _U('cl_lang_salary') .. ': $%s')
            :format(job.gradeLabel, job.grade, job.salary)

        table.insert(MenuElements, {
            label    = job.jobLabel,
            value    = 'open_job_choice',
            desc     = desc,
            info     = {
                job       = job.job,
                jobLabel  = job.jobLabel,
                grade     = job.grade
            },
            disabled = isDisabled
        })
    end

    if isMenuOpen then
        Menu.CloseAll()
    end

    Menu.Open(
        'default',
        GetCurrentResourceName(),
        'multi_job_main_menu',
        {
            title    = _U('cl_lang_3'),
            subtext  = '',
            align    = 'top-left',
            elements = MenuElements
        },
        function(data, menu)
            local val  = data.current.value
            local info = data.current.info

            if val == 'open_job_choice' and info then
                OpenChoiceMenu(info.job, info.jobLabel, info.grade)
            end
        end,
        function(data, menu)
            isMenuOpen = false
            menu.close()
        end
    )
    isMenuOpen = true
end

function OpenChoiceMenu(job, jobLabel, grade)
    local MenuElements = {
        {
            label = _U('cl_switch_job'),
            value = 'switch_job',
            desc  = (_U('cl_switch_your_job') .. ': %s'):format(jobLabel)
        },
        {
            label = _U('cl_delete_job'),
            value = 'delete_job',
            desc  = (_U('cl_delete_selected_job') .. ': %s'):format(jobLabel)
        }
    }

    Menu.CloseAll()
    Menu.Open(
        'default',
        GetCurrentResourceName(),
        'multi_job_choice_menu',
        {
            title    = _U('cl_job_actions'),
            subtext  = '',
            align    = 'top-left',
            elements = MenuElements
        },
        function(data, menu)
            local val = data.current.value

            if val == 'switch_job' then
                TriggerServerEvent('lr-multijobs:server:changeJob', job)
                Wait(100)
                ShowMultiJob()
                return
            end

            if val == 'delete_job' then
                TriggerServerEvent('lr-multijobs:server:deleteJob', job)
                Wait(100)
                ShowMultiJob()
                return
            end
        end,
        function(data, menu)
            menu.close()
            ShowMultiJob()
        end
    )
end

--------------------------------
-- Command or event to open the menu
--------------------------------
RegisterNetEvent('lr-multijobs:client:openmenu', function()
    ShowMultiJob()
end)

--------------------------------
-- Admin Job Menu Functions
--------------------------------

-- Event to display the list of jobs from society table
RegisterNetEvent('lr-multijobs:client:showJobsList')
AddEventHandler('lr-multijobs:client:showJobsList', function(jobs)
    if not jobs or #jobs == 0 then
        VORPcore.NotifyRightTip("No jobs found in society table", 4000)
        return
    end
    
    local MenuElements = {}
    local jobsByCategory = {}
    
    -- Group jobs by category
    for _, job in ipairs(jobs) do
        if not jobsByCategory[job.job] then
            jobsByCategory[job.job] = {}
        end
        table.insert(jobsByCategory[job.job], job)
    end
    
    -- Build menu elements
    for jobName, jobGrades in pairs(jobsByCategory) do
        table.insert(MenuElements, {
            label = jobName,
            value = "job_" .. jobName,
            desc = "Available grades: " .. #jobGrades,
            info = {
                grades = jobGrades
            }
        })
    end
    
    Menu.CloseAll()
    Menu.Open(
        'default',
        GetCurrentResourceName(),
        'society_jobs_list',
        {
            title = "Available Jobs",
            subtext = "Jobs available in society table",
            align = 'top-left',
            elements = MenuElements
        },
        function(data, menu)
            local val = data.current.value
            local info = data.current.info
            
            if val and val:sub(1, 4) == "job_" and info and info.grades then
                OpenJobGradesMenu(val:sub(5), info.grades)
            end
        end,
        function(data, menu)
            menu.close()
        end
    )
end)

-- Function to open job grades menu
function OpenJobGradesMenu(jobName, grades)
    local MenuElements = {}
    
    for _, grade in ipairs(grades) do
        table.insert(MenuElements, {
            label = "Grade: " .. grade.jobgrade,
            value = "grade_" .. grade.jobgrade,
            desc = "Salary: $" .. grade.salary,
            info = {
                job = jobName,
                grade = grade.jobgrade,
                salary = grade.salary
            }
        })
    end
    
    Menu.CloseAll()
    Menu.Open(
        'default',
        GetCurrentResourceName(),
        'society_job_grades',
        {
            title = "Job: " .. jobName,
            subtext = "Available grades",
            align = 'top-left',
            elements = MenuElements
        },
        function(data, menu)
            -- No actions on select, just viewing
        end,
        function(data, menu)
            menu.close()
            -- Return to jobs list
            TriggerServerEvent('lr-multijobs:server:refreshJobsList')
        end
    )
end

-- Event to open admin job assignment menu
RegisterNetEvent('lr-multijobs:client:openAdminMenu')
AddEventHandler('lr-multijobs:client:openAdminMenu', function(players, jobs, selectedPlayerId)
    if selectedPlayerId then
        -- If player is already selected, open jobs menu directly
        OpenPlayerJobAssignmentMenu(selectedPlayerId, jobs)
        return
    end
    
    if not players or #players == 0 then
        VORPcore.NotifyRightTip("No players online", 4000)
        return
    end
    
    local MenuElements = {}
    
    for _, player in ipairs(players) do
        table.insert(MenuElements, {
            label = player.name .. " (ID: " .. player.id .. ")",
            value = "player_" .. player.id,
            desc = "Select to assign jobs",
            info = {
                id = player.id
            }
        })
    end
    
    Menu.CloseAll()
    Menu.Open(
        'default',
        GetCurrentResourceName(),
        'admin_players_list',
        {
            title = "Player Selection",
            subtext = "Select a player to assign jobs",
            align = 'top-left',
            elements = MenuElements
        },
        function(data, menu)
            local val = data.current.value
            local info = data.current.info
            
            if val and val:sub(1, 7) == "player_" and info and info.id then
                OpenPlayerJobAssignmentMenu(info.id, jobs)
            end
        end,
        function(data, menu)
            menu.close()
        end
    )
end)

-- Function to open job assignment menu for a specific player
function OpenPlayerJobAssignmentMenu(playerId, jobs)
    if not jobs or #jobs == 0 then
        VORPcore.NotifyRightTip("No jobs available", 4000)
        return
    end
    
    local jobsByCategory = {}
    
    -- Group jobs by category
    for _, job in ipairs(jobs) do
        if not jobsByCategory[job.job] then
            jobsByCategory[job.job] = {}
        end
        table.insert(jobsByCategory[job.job], job)
    end
    
    local MenuElements = {}
    
    for jobName, jobGrades in pairs(jobsByCategory) do
        table.insert(MenuElements, {
            label = jobName,
            value = "job_" .. jobName,
            desc = "Available grades: " .. #jobGrades,
            info = {
                job = jobName,
                grades = jobGrades,
                playerId = playerId
            }
        })
    end
    
    Menu.CloseAll()
    Menu.Open(
        'default',
        GetCurrentResourceName(),
        'admin_job_assignment',
        {
            title = "Assign Job",
            subtext = "Select a job to assign to Player ID: " .. playerId,
            align = 'top-left',
            elements = MenuElements
        },
        function(data, menu)
            local val = data.current.value
            local info = data.current.info
            
            if val and val:sub(1, 4) == "job_" and info then
                OpenJobGradeAssignmentMenu(info.playerId, info.job, info.grades)
            end
        end,
        function(data, menu)
            menu.close()
        end
    )
end

-- Function to open job grade assignment menu
function OpenJobGradeAssignmentMenu(playerId, jobName, grades)
    local MenuElements = {}
    
    for _, grade in ipairs(grades) do
        table.insert(MenuElements, {
            label = "Grade: " .. grade.jobgrade,
            value = "grade_" .. grade.jobgrade,
            desc = "Salary: $" .. grade.salary,
            info = {
                job = jobName,
                grade = grade.jobgrade,
                salary = grade.salary,
                playerId = playerId
            }
        })
    end
    
    Menu.CloseAll()
    Menu.Open(
        'default',
        GetCurrentResourceName(),
        'admin_grade_assignment',
        {
            title = "Select Grade",
            subtext = "Job: " .. jobName .. " - Player ID: " .. playerId,
            align = 'top-left',
            elements = MenuElements
        },
        function(data, menu)
            local val = data.current.value
            local info = data.current.info
            
            if val and val:sub(1, 6) == "grade_" and info then
                -- Confirm assignment
                local confirmMenu = {
                    {
                        label = "Confirm Assignment",
                        value = "confirm",
                        desc = "Assign " .. info.job .. " (Grade " .. info.grade .. ") to Player ID: " .. info.playerId
                    },
                    {
                        label = "Cancel",
                        value = "cancel",
                        desc = "Return to grade selection"
                    }
                }
                
                Menu.CloseAll()
                Menu.Open(
                    'default',
                    GetCurrentResourceName(),
                    'admin_assignment_confirm',
                    {
                        title = "Confirm Assignment",
                        subtext = "Job: " .. info.job .. " - Grade: " .. info.grade,
                        align = 'top-left',
                        elements = confirmMenu
                    },
                    function(data2, menu2)
                        if data2.current.value == "confirm" then
                            -- Assign the job
                            TriggerServerEvent('lr-multijobs:server:adminAssignJob', info.playerId, info.job, info.grade, info.salary)
                            menu2.close()
                        elseif data2.current.value == "cancel" then
                            OpenJobGradeAssignmentMenu(info.playerId, info.job, grades)
                        end
                    end,
                    function(data2, menu2)
                        menu2.close()
                        OpenJobGradeAssignmentMenu(info.playerId, info.job, grades)
                    end
                )
            end
        end,
        function(data, menu)
            menu.close()
            OpenPlayerJobAssignmentMenu(playerId, grades)
        end
    )
end
