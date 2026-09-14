local root = debug.getinfo(1, 'S').source:sub(2):match('(.*/)') .. '../'
local commands, definition, calls = {}, nil, {}
local results = {}

_G.RegisterCommand = function(name, handler) commands[name] = handler end
_G.RegisterKeyMapping = function() end
_G.CreateThread = function(handler) handler() end

local initial = {
    active = { name = 'ambulance', onDuty = false },
    jobs = {
        { name = 'ambulance', jobLabel = 'EMS', gradeLabel = 'Paramedic', level = 2, pay = 175 },
        { name = 'mechanic', jobLabel = 'Mechanic', gradeLabel = 'Technician', level = 1, pay = 120 },
        { name = 'taxi', jobLabel = 'Taxi', gradeLabel = 'Driver', level = 1, pay = 90 },
        { name = 'lawyer', jobLabel = 'Lawyer', gradeLabel = 'Associate', level = 1, pay = 200 },
        { name = 'news', jobLabel = 'News', gradeLabel = 'Reporter', level = 1, pay = 110 },
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
equal(definition.height, 500, 'the compact roster does not reserve unnecessary vertical space')
equal(definition.description, '5 of 5 jobs saved', 'the header shows roster capacity')
local blocks = definition.navigation[1].content.blocks
local activeList = blocks[1]
local savedList = blocks[2]
equal(activeList.id, 'active-job', 'the current job is presented first')
equal(activeList.layout, 'list', 'the current job uses a compact row')
equal(activeList.items[1].label, 'EMS', 'the current job uses the server-provided job label')
equal(activeList.items[1].description, 'Paramedic', 'the current job shows its rank')
equal(activeList.items[1].metadata[1].value, 2, 'the current job displays its grade')
equal(activeList.items[1].metadata[2].value, '$175', 'the current job displays its pay')
equal(activeList.items[1].badge, 'Off duty', 'the current job exposes duty state once')
equal(activeList.items[1].actions[1].id, 'multijob:duty', 'the active job exposes duty control')
equal(savedList.id, 'saved-jobs', 'inactive jobs have a separate section')
equal(savedList.layout, 'list', 'saved jobs use compact rows')
truthy(savedList.searchable, 'search appears when four inactive jobs are available')
equal(savedList.items[1].label, 'Mechanic', 'the saved roster retains its server order')
equal(savedList.items[1].actions[1].id, 'multijob:select', 'an inactive job can be selected')
equal(savedList.items[1].actions[2].id, 'multijob:quit', 'an inactive job can be removed')
truthy(savedList.items[1].actions[2].confirm, 'removing a job requires confirmation')

equal(calls[2].name, 'qbmultijob:server:selectJob', 'select routes to the server')
equal(calls[2].value, 'mechanic', 'select sends only the selected job id')
equal(calls[3].name, 'qbmultijob:server:quitJob', 'quit routes to the server')
equal(calls[3].value, 'ambulance', 'quit sends only the selected job id')
equal(calls[4].name, 'qbmultijob:server:toggleDuty', 'duty routes to the active-job endpoint')
truthy(results.select.update.navigation, 'select returns a live AppShell update')
truthy(results.quit.update.navigation, 'quit returns a live AppShell update')
truthy(results.duty.update.navigation, 'duty returns a live AppShell update')
equal(#results.quit.update.navigation[1].content.blocks, 1, 'the empty saved-jobs section is omitted')
equal(results.quit.update.description, '1 of 5 jobs saved', 'live updates refresh roster capacity')

local clientFile = assert(io.open(root .. 'client.lua', 'r'))
local clientSource = clientFile:read('*a')
clientFile:close()
truthy(not clientSource:find('QB.nui.isAppOpen', 1, true),
    'job roster owns its AppShell active state without the broken qblib export call')

print(('qbmultijob client: %d assertions passed'):format(passed))
