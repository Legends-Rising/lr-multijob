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