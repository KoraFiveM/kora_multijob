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

-- Registers this resource-owned configuration with kora_lib without changing its public Config table.
if Kora and Kora.config and Kora.config.adopt then
    local config = Kora.config
    Config.maxJobs = config.integer(Config.maxJobs, {
        min = 0,
        label = 'Saved jobs per character', advanced = false,
        description = 'Maximum jobs a character can hold in addition to the civilian/unemployed fallback. Lowering this blocks further additions without removing saved jobs. Restart kora_multijob to apply saved changes.',
    })
    Config.command = config.string(Config.command, {
        minLength = 1,
        label = 'Job roster command', advanced = true,
        description = 'Chat command name without a leading slash that opens the job roster; also identifies its keyboard binding. Restart kora_multijob to apply saved changes.',
    })
    Config.keybind = config.string(Config.keybind, {
        label = 'Default job roster key', advanced = false,
        description = 'Default keyboard key for opening the job roster. Existing player key-binding choices remain in their FiveM settings. Restart kora_multijob to apply saved changes.',
    })
    Config.disabledDuty.police = config.boolean(Config.disabledDuty.police, {
        label = 'Lock police duty changes', advanced = true,
        description = 'Prevents players toggling police duty from the job roster; duty can still be controlled by other resources. Restart kora_multijob to apply saved changes.',
    })
    Config.icons.unemployed = config.string(Config.icons.unemployed, {
        label = 'Civilian job icon', advanced = true,
        description = 'Icon name sent to the job roster for the unemployed job identifier; use an icon supported by the roster interface. Restart kora_multijob to apply saved changes.',
    })
    Config.icons.police = config.string(Config.icons.police, {
        label = 'Police job icon', advanced = true,
        description = 'Icon name sent to the job roster for the police job identifier; use an icon supported by the roster interface. Restart kora_multijob to apply saved changes.',
    })
    Config.icons.ambulance = config.string(Config.icons.ambulance, {
        label = 'Ambulance job icon', advanced = true,
        description = 'Icon name sent to the job roster for the ambulance job identifier; use an icon supported by the roster interface. Restart kora_multijob to apply saved changes.',
    })
    Config.icons.mechanic = config.string(Config.icons.mechanic, {
        label = 'Mechanic job icon', advanced = true,
        description = 'Icon name sent to the job roster for the mechanic job identifier; use an icon supported by the roster interface. Restart kora_multijob to apply saved changes.',
    })
    Config.icons.tow = config.string(Config.icons.tow, {
        label = 'Tow truck job icon', advanced = true,
        description = 'Icon name sent to the job roster for the tow job identifier; use an icon supported by the roster interface. Restart kora_multijob to apply saved changes.',
    })
    Config.icons.taxi = config.string(Config.icons.taxi, {
        label = 'Taxi job icon', advanced = true,
        description = 'Icon name sent to the job roster for the taxi job identifier; use an icon supported by the roster interface. Restart kora_multijob to apply saved changes.',
    })
    Config.icons.lawyer = config.string(Config.icons.lawyer, {
        label = 'Lawyer job icon', advanced = true,
        description = 'Icon name sent to the job roster for the lawyer job identifier; use an icon supported by the roster interface. Restart kora_multijob to apply saved changes.',
    })
    Config.icons.realestateagent = config.string(Config.icons.realestateagent, {
        label = 'Real estate job icon', advanced = true,
        description = 'Icon name sent to the job roster for the realestateagent job identifier; use an icon supported by the roster interface. Restart kora_multijob to apply saved changes.',
    })
    Config.icons.government = config.string(Config.icons.government, {
        label = 'Government job icon', advanced = true,
        description = 'Icon name sent to the job roster for the government job identifier; use an icon supported by the roster interface. Restart kora_multijob to apply saved changes.',
    })
    Config.icons.news = config.string(Config.icons.news, {
        label = 'News job icon', advanced = true,
        description = 'Icon name sent to the job roster for the news job identifier; use an icon supported by the roster interface. Restart kora_multijob to apply saved changes.',
    })
    Config = config.adopt(Config)
end
