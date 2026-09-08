local root = debug.getinfo(1, 'S').source:sub(2):match('(.*/)') .. '../'
local commands, definition, calls = {}, nil, {}
local results = {}

_G.RegisterCommand = function(name, handler) commands[name] = handler end
_G.RegisterKeyMapping = function() end
_G.CreateThread = function(handler) handler() end

local initial = {
    active = { name = 'ambulance', onDuty = false },
    jobs = {
        { name = 'ambulance', label = 'EMS', rank = 'Paramedic', level = 2, pay = 175, dutyLocked = false },
        { name = 'mechanic', label = 'Mechanic', rank = 'Technician', level = 1, pay = 120, dutyLocked = false },
    },
}
local selected = {
    active = { name = 'mechanic', onDuty = false },
    jobs = initial.jobs,
}
local afterQuit = {
    active = { name = 'mechanic', onDuty = false },
    jobs = { initial.jobs[2] },
}
local onDuty = {
    active = { name = 'mechanic', onDuty = true },
    jobs = afterQuit.jobs,
}

_G.QB = {
    notify = { send = function() end },
    callback = { trigger = function(name, value)
        calls[#calls + 1] = { name = name, value = value }
        if name == 'qbmultijob:server:getRoster' then return initial end
        if name == 'qbmultijob:server:selectJob' then return true, selected end
        if name == 'qbmultijob:server:quitJob' then return true, afterQuit end
        if name == 'qbmultijob:server:toggleDuty' then return true, onDuty end
    end },
    nui = {
        registerApp = function(value) definition = value end,
        openApp = function()
            results.select = definition.onAction('multijob:select', { itemId = 'mechanic' })
            results.quit = definition.onAction('multijob:quit', { itemId = 'ambulance' })
            results.duty = definition.onAction('multijob:duty', { itemId = 'mechanic' })
            return { closed = true }
        end,
    },
}

dofile(root .. 'config.lua')
dofile(root .. 'client.lua')

local passed = 0
local function equal(actual, expected, message)
    if actual ~= expected then error(('%s: expected %s, got %s'):format(message, tostring(expected), tostring(actual)), 2) end
    passed = passed + 1
end
local function truthy(value, message)
    if not value then error(message, 2) end
    passed = passed + 1
end

commands[Config.command]()
equal(definition.id, 'qbmultijob:roster', 'the shared app has a namespaced id')
equal(definition.layout, 'compact', 'the roster uses compact AppShell layout')
local list = definition.navigation[1].content.blocks[2]
equal(list.type, 'list', 'the roster is a collection')
equal(list.layout, 'cards', 'the roster uses job cards')
truthy(list.searchable, 'the roster can be searched')
equal(list.items[1].actions[1].id, 'multijob:duty', 'the active job exposes duty control')
equal(list.items[2].actions[1].id, 'multijob:select', 'an inactive job can be selected')
equal(list.items[2].actions[2].id, 'multijob:quit', 'an inactive job can be removed')
truthy(list.items[2].actions[2].confirm, 'removing a job requires confirmation')

equal(calls[2].name, 'qbmultijob:server:selectJob', 'select routes to the server')
equal(calls[2].value, 'mechanic', 'select sends only the selected job id')
equal(calls[3].name, 'qbmultijob:server:quitJob', 'quit routes to the server')
equal(calls[3].value, 'ambulance', 'quit sends only the selected job id')
equal(calls[4].name, 'qbmultijob:server:toggleDuty', 'duty routes to the active-job endpoint')
truthy(results.select.update.navigation, 'select returns a live AppShell update')
truthy(results.quit.update.navigation, 'quit returns a live AppShell update')
truthy(results.duty.update.navigation, 'duty returns a live AppShell update')

local clientFile = assert(io.open(root .. 'client.lua', 'r'))
local clientSource = clientFile:read('*a')
clientFile:close()
truthy(not clientSource:find('QB.nui.isAppOpen', 1, true),
    'job roster owns its AppShell active state without the broken qblib export call')

print(('qbmultijob client: %d assertions passed'):format(passed))
