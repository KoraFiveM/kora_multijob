local APP_ID = 'qbmultijob:roster'
local currentRoster
local appActive = false

local function money(value)
    return ('$%d'):format(math.floor(tonumber(value) or 0))
end

local function appDefinition()
    local roster = currentRoster or { jobs = {}, active = {} }
    local active = roster.active or {}
    local activeItems = {}
    local savedItems = {}

    for _, job in ipairs(roster.jobs or {}) do
        local selected = job.name == active.name
        local dutyLocked = Config.disabledDuty[job.name] == true
        local actions = {}
        if not selected then
            actions[#actions + 1] = { id = 'multijob:select', label = 'Make active', icon = 'check', variant = 'primary' }
        elseif not dutyLocked then
            actions[#actions + 1] = {
                id = 'multijob:duty',
                label = active.onDuty and 'Go off duty' or 'Go on duty',
                icon = 'activity',
                variant = active.onDuty and 'secondary' or 'primary',
            }
        end
        if job.name ~= 'unemployed' and not selected then
            actions[#actions + 1] = { id = 'multijob:quit', label = 'Leave job', icon = 'trash-2', variant = 'destructive',
                confirm = ('Remove %s from your saved roster?'):format(job.jobLabel) }
        end

        local metadata = {
            { label = 'Grade', value = job.level },
            { label = 'Pay', value = money(job.pay) },
        }
        if selected and dutyLocked then
            metadata[#metadata + 1] = { label = 'Duty', value = 'Managed by job' }
        end

        local item = {
            id = job.name, label = job.jobLabel, description = job.gradeLabel,
            icon = Config.icons[job.name] or 'BriefcaseBusiness',
            tone = selected and (active.onDuty and 'success' or 'primary') or 'neutral',
            badge = selected and (active.onDuty and 'On duty' or 'Off duty') or nil,
            metadata = metadata,
            actions = actions,
        }

        if selected then
            activeItems[1] = item
        else
            savedItems[#savedItems + 1] = item
        end
    end

    local blocks = {
        {
            type = 'list', id = 'active-job', title = 'Current job', layout = 'list', items = activeItems,
            empty = 'Your current job is unavailable.',
        },
    }
    if #savedItems > 0 then
        blocks[#blocks + 1] = {
            type = 'list', id = 'saved-jobs', title = 'Saved jobs', layout = 'list',
            searchable = #savedItems >= 4, searchPlaceholder = 'Search jobs or ranks…', items = savedItems,
        }
    end

    return {
        id = APP_ID,
        title = 'Employment',
        description = ('%d of %d jobs saved'):format(#(roster.jobs or {}), Config.maxJobs + 1),
        icon = 'briefcase-business',
        layout = 'compact',
        placement = 'right',
        width = 500,
        height = 500,
        navigation = {
            {
                id = 'roster', label = 'My jobs', icon = 'briefcase-business', badge = #(roster.jobs or {}),
                content = {
                    blocks = blocks,
                },
            },
        },
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
            return { update = { navigation = updated.navigation, description = updated.description },
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
