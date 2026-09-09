Config = {
    maxJobs = 4, -- excludes the civilian/unemployed fallback
    command = 'multijob',
    keybind = 'J',
    disabledDuty = {
        police = true,
    },
    icons = {
        unemployed = 'BriefcaseBusiness', police = 'Shield', ambulance = 'HeartPulse',
        mechanic = 'Wrench', tow = 'Truck', taxi = 'Car', lawyer = 'Scale',
        realestateagent = 'House', government = 'Landmark', news = 'Newspaper',
    },
}

-- Registers this resource-owned configuration with qblib without changing its public Config table.
-- if QB and QB.config and QB.config.adopt then Config = QB.config.adopt(Config) end
