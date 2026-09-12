local root = debug.getinfo(1, 'S').source:sub(2):match('(.*/)') .. '../'
local handlers, writes, migrations = {}, {}, nil
local playerData = {
    citizenid = 'CID-1',
    job = { name = 'police', grade = { level = 2 }, onduty = false },
}

_G.CreateThread = function(handler) handler() end
_G.AddEventHandler = function(name, handler) handlers[name] = handler end
_G.LoadResourceFile = function(_, file)
    if file == 'sql/001_jobs.sql' then return 'CREATE TABLE IF NOT EXISTS `qbmultijob_jobs` (`citizenid` VARCHAR(64));' end
    if file == 'sql/002_roster_names.sql' then return 'ALTER TABLE `qbmultijob_jobs` ADD COLUMN IF NOT EXISTS `name` VARCHAR(128);' end
end
_G.GetCurrentResourceName = function() return 'qbmultijob' end
_G.json = {
    encode = function(value)
        local police = value.police
        return ('police:%s:%s'):format(police.name, police.level)
    end,
    decode = function() return {} end,
}

local exported = {}
_G.exports = setmetatable({
    qbcore = {
        getPlayerData = function(_, src) return src == 1 and playerData or nil end,
        getPlayers = function() return {} end,
        hasPermission = function() return true end,
    },
}, { __call = function(_, name, fn) exported[name] = fn end })

_G.QB = {
    sql = {
        ready = function() return true end,
        migrate = function(resource, definitions)
            assert(resource == 'qbmultijob', 'the migration resource must be qbmultijob')
            migrations = definitions
            return true
        end,
        migrateFiles = function(resource, definitions)
            local prepared = {}
            for index = 1, #definitions do
                local definition = definitions[index]
                prepared[index] = {
                    version = definition.version,
                    name = definition.name,
                    sql = LoadResourceFile(resource, definition.file),
                }
            end
            migrations = prepared
            return true
        end,
        single = function() return nil end,
        upsert = function(_, _, rows)
            writes[#writes + 1] = rows[1]
            return 1
        end,
    },
    shared = {
        get = function(_, name)
            local jobs = {
                police = { label = 'Police', grades = { [2] = { name = 'Officer', payment = 100 } } },
                unemployed = { label = 'Unemployed', grades = { [1] = { name = 'Unemployed', payment = 0 } } },
            }
            return jobs[name]
        end,
    },
    callback = { register = function() end },
    notify = { send = function() end },
    commands = { add = function() end },
}

dofile(root .. 'config.lua')
dofile(root .. 'server.lua')

assert(migrations and #migrations == 2, 'both qbmultijob migrations must be registered')
assert(migrations[2].sql:match('^ALTER TABLE') and migrations[2].sql:match('ADD COLUMN IF NOT EXISTS'), 'the roster-name migration must be retry-safe DDL')
assert(not migrations[2].sql:match('UPDATE'), 'the roster-name migration must not contain non-DDL statements')

handlers['QBCore:Server:OnJobUpdate'](1)

assert(#writes == 1, 'a qbcore job update must write the roster immediately')
assert(writes[1].pk == 'CID-1', 'the roster write must use the character citizenid')
assert(writes[1].cols.jobs == 'police:police:2', 'the roster must retain qbcore’s one-based grade')
print('qbmultijob server: job updates persist immediately')
