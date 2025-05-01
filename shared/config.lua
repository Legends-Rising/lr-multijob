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