---@type table<integer, { citizenid: string, jobs: table<string, table> }>
local rosterBySource = {}
local schemaReady = false
local saveActiveJob

-- local function checksum(value)
--     local hash = 2166136261
--     for i = 1, #value do hash = ((hash ~ value:byte(i)) * 16777619) & 0xFFFFFFFF end
--     return ('%08x'):format(hash)
-- end
-- 
-- CreateThread(function()
--     local ready = QB.sql.ready(60000)
--     if not ready then
--         print('^1[qbmultijob]^7 qbsql was not ready; multi-job persistence is unavailable.')
--         return
--     end
--     local sql = assert(LoadResourceFile(GetCurrentResourceName(), 'sql/001_jobs.sql'), 'missing qbmultijob migration')
--     local names = assert(LoadResourceFile(GetCurrentResourceName(), 'sql/002_roster_names.sql'), 'missing qbmultijob roster-name migration')
--     local _, err = QB.sql.migrate(GetCurrentResourceName(), {
--         { version = 1, name = 'jobs', sql = sql, checksum = checksum(sql) },
--         { version = 2, name = 'roster_names', sql = names, checksum = checksum(names) },
--     })
--     if err then
--         print(('^1[qbmultijob]^7 migration failed: %s'):format(err))
--         return
--     end
--     schemaReady = true
-- end)

local function player(src)
    return exports.qbcore:getPlayerData(src)
end

local function jobRecord(name, level)
    local definition = QB.shared.get('jobs', name)
    level = tonumber(level)
    local grade = definition and definition.grades and definition.grades[level]
    if not definition or not grade then return nil end
    return { name = name, level = level, jobLabel = definition.label, gradeLabel = grade.label, pay = grade.pay or grade.payment }
end

local function save(src)
    assert(src, 'source is required')
    assert(type(src) == 'number' or type(src) == 'string' and #src == 8, 'source must be a number or string')
    local cid = type(src) == 'number' and player(src).citizenid or src
    if not rosterBySource[src] then return false, 'roster not loaded' end
    QB.sql.query('UPDATE qbmultijob_jobs SET jobs = ? WHERE citizenid = ?', { json.encode(rosterBySource[src]), cid })
end

local function load(src)
    assert(src, 'source is required')
    if rosterBySource[src] then return rosterBySource[src] end
    assert(type(src) == 'number' or type(src) == 'string' and #src == 8, 'source must be a number or string')
    local cid = type(src) == 'number' and player(src).citizenid or src

    if not rosterBySource[src] then
        local row = QB.sql.query('SELECT jobs FROM qbmultijob_jobs WHERE citizenid = ?', { cid })
        if row and row[1] and type(row[1].jobs) == 'string' then
            rosterBySource[src] = json.decode(row[1].jobs)
        elseif not row or #row == 0 then
            local pData = player(src)
            local job = pData.job
            local name = pData.charinfo.firstname .. ' ' .. pData.charinfo.lastname
            rosterBySource[src] = {jobRecord(job.name, job.grade and job.grade.level)}
            QB.sql.query('INSERT INTO qbmultijob_jobs (citizenid, jobs, name) VALUES (?, ?, ?)', { cid, json.encode(rosterBySource[src]), name })
        end
    end
    return rosterBySource[src]
end

local function hasJob(src, name)
    if not rosterBySource[src] then
        rosterBySource[src] = load(src)
    end
    for _, jobData in pairs(rosterBySource[src]) do
        if jobData.name == name then
            return true
        end
    end
    return false
end

local function getOwnedJobData(src, name)
    if not rosterBySource[src] then
        rosterBySource[src] = load(src)
    end
    for _, jobData in pairs(rosterBySource[src]) do
        if jobData.name == name then
            return {name = jobData.name, level = jobData.level}
        end
    end
    return nil
end
saveActiveJob = function(src)
    src = tonumber(src)
    if not rosterBySource[src] then
        rosterBySource[src] = load(src)
    end
    local active = player(src).job
    local hasJob = false
    for key, jobData in pairs(rosterBySource[src]) do
        if jobData.name == active.name then
            rosterBySource[src][key] = jobRecord(active.name, active.grade and active.grade.level)
            hasJob = true
        end
    end
    if not hasJob then
        table.insert(rosterBySource[src], jobRecord(active.name, active.grade and active.grade.level))
    end
    save(src)
    return true
end

local function view(src)
    if not rosterBySource[src] then
        rosterBySource[src] = load(src)
    end
    table.sort(rosterBySource[src], function(a, b) return a.jobLabel < b.jobLabel end)
    local data = player(src)
    local active = data and data.job or {}
    return { jobs = rosterBySource[src], active = { name = active.name, onDuty = active.onduty == true } }
end

local function notify(src, type_, message)
    QB.notify.send(src, { title = 'Employment', type = type_, message = message })
end

QB.callback.register('qbmultijob:server:getRoster', function(src)
    return view(src)
end)

QB.callback.register('qbmultijob:server:selectJob', function(src, name)
    assert(type(name) == 'string' and name ~= 'unemployed', 'invalid job')
    assert(hasJob(src, name), 'that job is not in your roster')
    local jobData = getOwnedJobData(src, name)
    assert(jobData, 'could not retrieve job data')
    exports.qbcore:setJob(src, name, jobData.level)
    return {true, view(src)}
end)

QB.callback.register('qbmultijob:server:toggleDuty', function(src)
    local data = player(src)
    local job = data and data.job
    if not job then return false, 'character not loaded' end
    if Config.disabledDuty[job.name] then return false, 'duty changes are disabled for this job' end
    local ok, err = exports.qbcore:setJobDuty(src, not job.onduty)
    if not ok then return false, err or 'could not change duty status' end
    return true, view(src)
end)

QB.callback.register('qbmultijob:server:quitJob', function(src, name)
    if type(name) ~= 'string' or name == 'unemployed' then return false, 'that job cannot be removed' end
    local roster, err = load(src)
    if not roster then return false, err end
    if not roster[name] then return false, 'that job is not in your roster' end
    local active = player(src).job
    if active and active.name == name then return false, 'choose another active job before removing this one' end
    roster[name] = nil
    if not save(src) then return false, 'could not save your roster' end
    notify(src, 'info', 'Job removed from your roster.')
    return true, view(src)
end)

local function canManage(src) return src == 0 or exports.qbcore:hasPermission(src, 'admin') end

local function addJob(src, name, level)
    assert(src, 'source is required')
    assert(name, 'job name is required')
    assert(level, 'job level is required')
    if not rosterBySource[src] then 
        rosterBySource[src] = load(src)
    end
    if #rosterBySource[src] >= Config.maxJobs + 1 then return false, 'job roster is full' end
    rosterBySource[src][#rosterBySource[src] + 1] = jobRecord(name, level)
    save(src)
    return true
end

for _, command in ipairs({
    { name = 'givejob', help = 'Add or update a player job', handler = function(src, args)
        local target, level = tonumber(args[1]), tonumber(args[3])
        if not target or not args[2] or not level or not exports.qbcore:getPlayerData(target) then return notify(src, 'error', 'Usage: /givejob [id] [job] [grade]') end
        local ok, err = addJob(target, args[2], level)
        notify(src, ok and 'success' or 'error', ok and 'Job saved.' or err)
        if ok then notify(target, 'success', 'A job was added to your roster.') end
    end },
    { name = 'removejob', help = 'Remove a player job', handler = function(src, args)
        local target, name = tonumber(args[1]), args[2]
        if not target or not name then return notify(src, 'error', 'Usage: /removejob [id] [job]') end
        local roster = load(target)
        if not roster or not roster[name] or name == 'unemployed' then return notify(src, 'error', 'Player does not have that removable job.') end
        if exports.qbcore:getPlayerData(target, { 'job', 'name' }) == name then return notify(src, 'error', 'Player must change active job first.') end
        roster[name] = nil
        local ok = save(target)
        notify(src, ok and 'success' or 'error', ok and 'Job removed.' or 'Could not save roster.')
    end },
}) do
    QB.commands.add(command.name, command.help, nil, false, function(src, args)
        if not canManage(src) then return notify(src, 'error', 'You do not have permission for this command.') end
        command.handler(src, args)
    end)
end

local function invalidate(src)
    src = tonumber(src)
    if not src then return false end
    rosterBySource[src] = nil
    return true
end

local function getEmployees(jobName)
    local time1 = GetGameTimer()
    local result = QB.sql.query([[
        SELECT
            name,
            citizenid,
            JSON_UNQUOTE(JSON_EXTRACT(jt.job, '$.jobLabel')) AS jobLabel,
            JSON_UNQUOTE(JSON_EXTRACT(jt.job, '$.name')) AS jobName,
            CAST(JSON_EXTRACT(jt.job, '$.pay') AS UNSIGNED) AS pay,
            CAST(JSON_EXTRACT(jt.job, '$.level') AS UNSIGNED) AS level
        FROM qbmultijob_jobs
        JOIN JSON_TABLE(
            jobs,
            '$[*]' COLUMNS (
                job JSON PATH '$'
            )
        ) AS jt
        WHERE JSON_UNQUOTE(JSON_EXTRACT(jt.job, '$.name')) = ?
    ]], { jobName })
    local time2 = GetGameTimer()
    return result, time2 - time1
end

local function updateActiveOffline(citizenid, name, level)
    local offline = exports['qb-core']:GetOfflinePlayerByCitizenId(citizenid)
    if not offline then return false, 'could not load offline player' end
    if not offline.Functions.SetJob(name, level - 1) then return false, 'could not update offline job' end
    if not offline.Functions.Save() then return false, 'could not save offline player' end
    return true
end

---Adds or promotes an employee job using a citizenid. If that job is active,
---the active job is updated too (and persisted for offline characters).
local function setEmployeeJob(citizenid, name, level)
    if type(citizenid) ~= 'string' or citizenid == '' then return false, 'invalid citizenid' end
    local record = jobRecord(name, level)
    if not rosterBySource[citizenid] then 
        rosterBySource[citizenid] = load(citizenid)
    end
    for key, jobData in pairs(rosterBySource[citizenid]) do
        if name == jobData.name then
            rosterBySource[citizenid][key] = record
            break
        end
    end
    return save(citizenid), 'could not save roster'
end

local function removeEmployeeJob(citizenid, name)
    if type(citizenid) ~= 'string' or citizenid == '' then return false, 'invalid citizenid' end
    if not rosterBySource[citizenid] then
        rosterBySource[citizenid] = load(citizenid)
    end
    for key, jobData in pairs(rosterBySource[citizenid]) do
        if name == jobData.name then
            rosterBySource[citizenid][key] = nil
            break
        end
    end
    local player = exports['qb-core']:GetPlayerByCitizenId(citizenid) or exports['qb-core']:GetOfflinePlayerByCitizenId(citizenid)
    if player.PlayerData.job.name == name then
        player.Functions.SetJob('unemployed', 0)
        player.Functions.Save()
    end
    return save(citizenid), 'could not save roster'
end

AddEventHandler('QBCore:Server:OnPlayerUnload', function(src) invalidate(src) end)
AddEventHandler('qbcore:server:playerLoaded', function(src)
    invalidate(src)
    saveActiveJob(src)
end)
AddEventHandler('QBCore:Server:OnJobUpdate', function(src)
    local ok, err = saveActiveJob(src)
    if not ok and err ~= 'job storage is still starting' and err ~= 'character or job is unavailable' then
        print(('^1[qbmultijob]^7 could not save job roster for %s: %s'):format(tostring(src), err))
    end
end)
AddEventHandler('playerDropped', function() invalidate(source) end)

CreateThread(function()
    --while not schemaReady do Wait(50) end
    -- A player can be assigned a job while qbsql is still coming online. Catch
    -- those already-online characters as soon as the migration has completed.
    for _, src in ipairs(exports.qbcore:getPlayers()) do saveActiveJob(src) end
end)

exports('addJob', addJob)
exports('getRoster', function(src) return view(src) end)
exports('getEmployees', getEmployees)
exports('setEmployeeJob', setEmployeeJob)
exports('removeEmployeeJob', removeEmployeeJob)
exports('invalidate', invalidate)
