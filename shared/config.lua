Config = {}

Config.locale = 'en'
Config.Debug = true

-- Group-based job slot limits
Config.GroupMaxJobs = {
    ['user'] = 3,      -- Default users can have 3 jobs
    ['vip'] = 5,       -- VIP users can have 5 jobs
    ['admin'] = 10     -- Admins can have 10 jobs
}

Config.DefaultMaxJobs = 3  -- Default max jobs if group not found

-- Toggle job-conflict system
Config.EnableJobConflicts = false   -- Set to true to prevent players from holding clashing jobs

-- Define clashing jobs. Use job names as they appear in the `society` table.
-- Example below: a blacksmith cannot also be a miner or smelter, and vice-versa.
-- Leave the table empty (or keep EnableJobConflicts = false) to disable this check.
Config.JobConflicts = {
    -- ['blacksmith'] = { 'miner', 'smelter' },
    -- ['miner']      = { 'blacksmith' }        -- both directions not required but recommended
}

-- Whether to use the `society` SQL table for job validation & salaries.
-- If set to `false` the script will **not** look in the `society` table when
-- adding / changing jobs and will use the `Config.DefaultSalary` value for all
-- jobs in the menu instead.
Config.UseSocietyTable = true   -- set to false if you don't have, or don't want to use, the society table

-- Whether to use the `dl-society` script and its database tables (dl_jobs, dl_job_grades)
-- When enabled, this will take precedence over the standard society table
Config.UseDLSociety = false     -- set to true if you have dl-society installed and want to use it

-- Default salary that will be shown in the menu when `UseSocietyTable` is false
Config.DefaultSalary = 0