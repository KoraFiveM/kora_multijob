local APP_ID = 'qbmultijob:roster'
local currentRoster
local appActive = false

local function money(value)
    return ('$%d'):format(math.floor(tonumber(value) or 0))
end

local function appDefinition()
    local roster = currentRoster or { jobs = {}, active = {} }
    local active = roster.active or {}
    local cards = {}
    local activeJob

    for _, job in ipairs(roster.jobs or {}) do
        local selected = job.name == active.name
        if selected then activeJob = job end
        local actions = {}
        if not selected then
            actions[#actions + 1] = { id = 'multijob:select', label = 'Make active', icon = 'check', variant = 'primary' }
        elseif not job.dutyLocked then
            actions[#actions + 1] = { id = 'multijob:duty', label = active.onDuty and 'Go off duty' or 'Go on duty', icon = 'activity' }
        end
        if job.name ~= 'unemployed' and not selected then
            actions[#actions + 1] = { id = 'multijob:quit', label = 'Leave job', icon = 'trash-2', variant = 'destructive',
                confirm = ('Remove %s from your saved roster?'):format(job.label) }
        end
        cards[#cards + 1] = {
            id = job.name, label = job.label, description = job.rank,
            icon = job.icon, tone = selected and 'primary' or 'neutral',
            badge = selected and (active.onDuty and 'Active · On duty' or 'Active · Off duty') or nil,
            metadata = {
                { label = 'Grade', value = job.level },
                { label = 'Pay', value = money(job.pay) },
                { label = 'Duty', value = job.dutyLocked and 'Managed by job' or 'Self-service' },
            },
            actions = actions,
        }
    end

    return {
        id = APP_ID,
        title = 'Employment',
        description = 'Saved job roster',
        icon = 'briefcase-business',
        layout = 'compact',
        placement = 'right',
        width = 500,
        height = 720,
        navigation = {
            {
                id = 'roster', label = 'My jobs', icon = 'briefcase-business', badge = #cards,
                content = {
                    title = 'Job roster',
                    description = 'Choose your active role, manage duty, or remove an inactive job.',
                    blocks = {
                        { type = 'stats', items = {
                            { label = 'Saved jobs', value = #cards, icon = 'briefcase-business' },
                            { label = 'Active role', value = activeJob and activeJob.label or active.name or 'None', icon = 'check', tone = 'primary' },
                            { label = 'Duty status', value = active.onDuty and 'On duty' or 'Off duty', icon = 'activity', tone = active.onDuty and 'success' or 'neutral' },
                        } },
                        { type = 'list', id = 'job-roster', layout = 'cards', searchable = true,
                            searchPlaceholder = 'Search jobs or ranks…', items = cards, empty = 'No saved jobs are available.' },
                    },
                },
            },
        },
        footer = ('Up to %d non-civilian jobs can be saved. Changes are verified by the server.'):format(Config.maxJobs),
        onAction = function(actionId, context)
            local jobName = context and context.itemId
            local callback
            if actionId == 'multijob:select' then callback = 'qbmultijob:server:selectJob'
            elseif actionId == 'multijob:duty' then callback = 'qbmultijob:server:toggleDuty'
            elseif actionId == 'multijob:quit' then callback = 'qbmultijob:server:quitJob'
            else error('That roster action is no longer available.') end

            local ok, result
            if actionId == 'multijob:duty' then ok, result = QB.callback.trigger(callback)
            else ok, result = QB.callback.trigger(callback, jobName) end
            if not ok or type(result) ~= 'table' then
                return { notice = { tone = 'destructive', message = type(result) == 'string' and result or 'The roster change was declined.' } }
            end
            currentRoster = result
            local updated = appDefinition()
            return { update = { navigation = updated.navigation, footer = updated.footer },
                notice = { tone = 'success', message = 'Job roster updated.' } }
        end,
    }
end

local function openMenu()
    if appActive then return end
    appActive = true

    CreateThread(function()
        local ok, err = pcall(function()
            local roster = QB.callback.trigger('qbmultijob:server:getRoster')
            if type(roster) ~= 'table' then
                QB.notify.send({ title = 'Employment', type = 'error', message = 'Your job roster is unavailable.' })
                return
            end

            currentRoster = roster
            QB.nui.registerApp(appDefinition())
            QB.nui.openApp(APP_ID)
        end)

        currentRoster = nil
        appActive = false

        if not ok then
            print(('^1[qbmultijob]^7 Could not open the job roster: %s'):format(tostring(err)))
            QB.notify.send({ title = 'Employment', type = 'error', message = 'Your job roster could not be opened.' })
        end
    end)
end

RegisterCommand(Config.command, openMenu, false)
RegisterKeyMapping(Config.command, 'Open job roster', 'keyboard', Config.keybind)
