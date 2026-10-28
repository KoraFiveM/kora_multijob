local root = debug.getinfo(1, 'S').source:sub(2):match('(.*/)') .. '../'
local handlers, writes, migrations = {}, {}, nil
local playerData = {
    citizenid = 'CID-1',
    job = { name = 'police', grade = { level = 2 }, onduty = false },
}

_G.CreateThread = function(handler) handler() end
_G.AddEventHandler = function(name, handler) handlers[name] = handler end
_G.LoadResourceFile = function(_, file)
    local handle = assert(io.open(root .. file, 'r'))
    local contents = handle:read('*a')
    handle:close()
    return contents
end
_G.GetCurrentResourceName = function() return 'kora_multijob' end
_G.json = {
    encode = function(value)
        local police = value.police
        assert(police.gradeLabel == 'Officer' and police.jobLabel == 'Police' and police.pay == 100,
            'saved records must cache the current job display data')
        return ('police:%s:%s'):format(police.name, police.level)
    end,
    decode = function() return {} end,
}

local exported = {}
_G.exports = setmetatable({
    kora_core = {
        getPlayerData = function(_, src) return src == 1 and playerData or nil end,
        getPlayers = function() return {} end,
        hasPermission = function() return true end,
    },
}, { __call = function(_, name, fn) exported[name] = fn end })

_G.QB = {
    sql = {
        ready = function() return true end,
        migrate = function(resource, definitions)
            assert(resource == 'kora_multijob', 'the migration resource must be qbmultijob')
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

assert(migrations and #migrations == 1, 'the unreleased qbmultijob schema must be one migration')
assert(migrations[1].sql:match('CREATE TABLE IF NOT EXISTS'), 'the initial migration must be retry-safe DDL')
assert(migrations[1].sql:match('`name` VARCHAR%(128%)'), 'the initial migration must include roster names')

handlers['QBCore:Server:OnJobUpdate'](1)

assert(#writes == 1, 'a qbcore job update must write the roster immediately')
assert(writes[1].pk == 'CID-1', 'the roster write must use the character citizenid')
assert(writes[1].cols.jobs == 'police:police:2', 'the roster must retain qbcore’s one-based grade')
print('qbmultijob server: job updates persist immediately')
