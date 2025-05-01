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
RegisterCommand('myjobs', function()
    ShowMultiJob()
end)

RegisterNetEvent('lr-multijobs:client:openmenu', function()
    ShowMultiJob()
end)
