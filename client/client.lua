local APP_ID = 'kora_multijob:roster'
local currentRoster
local appActive = false

local function money(value)
    return Kora.lang('currency', math.floor(tonumber(value) or 0))
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
            actions[#actions + 1] = {
                id = 'multijob:select',
                label = Kora.lang('make_active'),
                icon = 'check',
                variant = 'primary',
            }
        elseif not dutyLocked then
            actions[#actions + 1] = {
                id = 'multijob:duty',
                label = active.onDuty and Kora.lang('go_off_duty') or Kora.lang('go_on_duty'),
                icon = 'activity',
                variant = active.onDuty and 'secondary' or 'primary',
            }
        end
        if job.name ~= 'unemployed' and not selected then
            actions[#actions + 1] = {
                id = 'multijob:quit',
                label = Kora.lang('leave_job'),
                icon = 'trash-2',
                variant = 'destructive',
                confirm = Kora.lang('remove_confirmation', job.jobLabel),
            }
        end

        local metadata = {
            { label = Kora.lang('grade'), value = job.level },
            { label = Kora.lang('pay'), value = money(job.pay) },
        }
        if selected and dutyLocked then
            metadata[#metadata + 1] = {
                label = Kora.lang('duty'),
                value = Kora.lang('managed_by_job'),
            }
        end

        local item = {
            id = job.name,
            label = job.jobLabel,
            description = job.gradeLabel,
            icon = Config.icons[job.name] or 'BriefcaseBusiness',
            tone = selected and (active.onDuty and 'success' or 'primary') or 'neutral',
            badge = selected and (active.onDuty and Kora.lang('on_duty') or Kora.lang('off_duty')) or nil,
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
            type = 'list',
            id = 'active-job',
            title = Kora.lang('current_job'),
            layout = 'list',
            items = activeItems,
            empty = Kora.lang('current_job_unavailable'),
        },
    }
    if #savedItems > 0 then
        blocks[#blocks + 1] = {
            type = 'list',
            id = 'saved-jobs',
            title = Kora.lang('saved_jobs'),
            layout = 'list',
            searchable = #savedItems >= 4,
            searchPlaceholder = Kora.lang('search_jobs'),
            items = savedItems,
        }
    end
    local count = #(roster.jobs or {})
    local heights = { 500, 500, 525, 600, 725 }
    return {
        id = APP_ID,
        title = Kora.lang('title'),
        description = Kora.lang('jobs_saved', count, Config.maxJobs + 1),
        icon = 'briefcase-business',
        layout = 'compact',
        placement = 'right',
        width = 500,
        height = heights[math.min(count, #heights)] or heights[1],
        navigation = {
            {
                id = 'roster',
                label = Kora.lang('my_jobs'),
                icon = 'briefcase-business',
                badge = count,
                content = {
                    blocks = blocks,
                },
            },
        },
        onAction = function(actionId, context)
            local jobName = context and context.itemId
            local callback
            if actionId == 'multijob:select' then callback = 'kora_multijob:server:selectJob'
            elseif actionId == 'multijob:duty' then callback = 'kora_multijob:server:toggleDuty'
            elseif actionId == 'multijob:quit' then callback = 'kora_multijob:server:quitJob'
            else error('That roster action is no longer available.') end

            local ok, result
            if actionId == 'multijob:duty' then ok, result = Kora.callback.trigger(callback)
            else ok, result = Kora.callback.trigger(callback, jobName) end
            if not ok or type(result) ~= 'table' then
                local message = type(result) == 'string' and result or 'roster_change_declined'
                return {
                    notice = {
                        tone = 'destructive',
                        message = Kora.lang(message),
                    },
                }
            end
            currentRoster = result
            local updated = appDefinition()
            return {
                update = {
                    navigation = updated.navigation,
                    description = updated.description,
                },
                notice = {
                    tone = 'success',
                    message = Kora.lang('roster_updated'),
                },
            }
        end,
    }
end

local function openMenu()
    if appActive then return end
    appActive = true

    CreateThread(function()
        local ok, err = pcall(function()
            local roster = Kora.callback.trigger('kora_multijob:server:getRoster')
            if type(roster) ~= 'table' then
                Kora.notify.send({
                    title = Kora.lang('title'),
                    type = 'error',
                    message = Kora.lang('roster_unavailable'),
                })
                return
            end

            currentRoster = roster
            Kora.nui.registerApp(appDefinition())
            Kora.nui.openApp(APP_ID)
        end)

        currentRoster = nil
        appActive = false

        if not ok then
            print(('^1[kora_multijob]^7 Could not open the job roster: %s'):format(tostring(err)))
            Kora.notify.send({
                title = Kora.lang('title'),
                type = 'error',
                message = Kora.lang('roster_open_failed'),
            })
        end
    end)
end

RegisterCommand(Config.command, openMenu, false)
RegisterKeyMapping(Config.command, Kora.lang('open_job_roster'), 'keyboard', Config.keybind)

RegisterNetEvent('kora_multijob:client:notify', function(type_, key, ...)
    Kora.notify.send({
        title = Kora.lang('title'),
        type = type_,
        message = Kora.lang(key, ...),
    })
end)
