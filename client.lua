local open = false

local function send(action, data)
    SendNUIMessage({ action = action, data = data })
end

local function close()
    if not open then return end
    open = false
    SetNuiFocus(false, false)
    send('qbmultijob:close')
end

local function openMenu()
    if open then return end
    local roster = QB.callback.trigger('qbmultijob:server:getRoster')
    if type(roster) ~= 'table' then
        QB.notify.send({ title = 'Employment', type = 'error', message = 'Your job roster is unavailable.' })
        return
    end
    open = true
    QBTheme.refresh()
    send('qbmultijob:open', roster)
    SetNuiFocus(true, true)
end

RegisterCommand(Config.command, openMenu, false)
RegisterKeyMapping(Config.command, 'Open job roster', 'keyboard', Config.keybind)

RegisterNUICallback('qbmultijob:close', function(_, cb) close(); cb({ ok = true }) end)

RegisterNUICallback('qbmultijob:selectJob', function(data, cb)
    local ok, result = QB.callback.trigger('qbmultijob:server:selectJob', data and data.name)
    cb({ ok = ok == true, roster = type(result) == 'table' and result or nil, error = type(result) == 'string' and result or nil })
end)

RegisterNUICallback('qbmultijob:toggleDuty', function(_, cb)
    local ok, result = QB.callback.trigger('qbmultijob:server:toggleDuty')
    cb({ ok = ok == true, roster = type(result) == 'table' and result or nil, error = type(result) == 'string' and result or nil })
end)

RegisterNUICallback('qbmultijob:quitJob', function(data, cb)
    local ok, result = QB.callback.trigger('qbmultijob:server:quitJob', data and data.name)
    cb({ ok = ok == true, roster = type(result) == 'table' and result or nil, error = type(result) == 'string' and result or nil })
end)

AddEventHandler('qbmultijob:client:theme', QBTheme.refresh)
AddEventHandler('onResourceStop', function(resource) if resource == GetCurrentResourceName() then close() end end)
