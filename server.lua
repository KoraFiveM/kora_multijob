---@type table<integer, { citizenid: string, jobs: table<string, table> }>
local rosterBySource = {}
local schemaReady = false
local saveActiveJob

local function checksum(value)
    local hash = 2166136261
    for i = 1, #value do hash = ((hash ~ value:byte(i)) * 16777619) & 0xFFFFFFFF end
    return ('%08x'):format(hash)
end

CreateThread(function()
    local ready = QB.sql.ready(60000)
    if not ready then
        print('^1[qbmultijob]^7 qbsql was not ready; multi-job persistence is unavailable.')
        return
    end
    local sql = assert(LoadResourceFile(GetCurrentResourceName(), 'sql/001_jobs.sql'), 'missing qbmultijob migration')
    local names = assert(LoadResourceFile(GetCurrentResourceName(), 'sql/002_roster_names.sql'), 'missing qbmultijob roster-name migration')
    local _, err = QB.sql.migrate(GetCurrentResourceName(), {
        { version = 1, name = 'jobs', sql = sql, checksum = checksum(sql) },
        { version = 2, name = 'roster_names', sql = names, checksum = checksum(names) },
    })
    if err then
        print(('^1[qbmultijob]^7 migration failed: %s'):format(err))
        return
    end
    schemaReady = true
end)

local function player(src)
    return exports.qbcore:getPlayerData(src)
end

local function jobRecord(name, level)
    local definition = QB.shared.get('jobs', name)
    level = tonumber(level)
    local grade = definition and definition.grades and definition.grades[level]
    if not definition or not grade then return nil end
    return { name = name, level = level }
end

local function playerName(data)
    if type(data) ~= 'table' then return 'unknown' end
    if type(data.name) == 'string' and data.name ~= '' and data.name ~= 'unknown' then return data.name end
    local charinfo = data.charinfo or {}
    local name = ('%s %s'):format(charinfo.firstname or '', charinfo.lastname or ''):gsub('^%s*(.-)%s*$', '%1')
    return name ~= '' and name or 'unknown'
end

local function normalize(stored)
    local result = {}
    for name, record in pairs(type(stored) == 'table' and stored or {}) do
        local normalized = jobRecord(name, record.level)
        if normalized then result[name] = normalized end
    end
    return result
end

local function save(src)
    local data = player(src)
    local entry = rosterBySource[src]
    if not data or not data.citizenid or not entry or entry.citizenid ~= data.citizenid then return false end
    entry.name = playerName(data)
    local _, err = QB.sql.upsert('qbmultijob_jobs', 'citizenid', {
        { pk = entry.citizenid, cols = { name = entry.name, jobs = json.encode(entry.jobs) } },
    })
    return not err
end

local function load(src)
    if not schemaReady then return nil, 'job storage is still starting' end
    local data = player(src)
    if not data or not data.citizenid then return nil, 'character not loaded' end
    local citizenid = data.citizenid
    local cached = rosterBySource[src]
    if cached and cached.citizenid == citizenid then return cached.jobs end
    rosterBySource[src] = nil

    local row, err = QB.sql.single('SELECT `name`, `jobs` FROM `qbmultijob_jobs` WHERE `citizenid` = ?', { citizenid })
    if err then return nil, 'could not load saved jobs' end

    -- SQL yielded. Do not install character A's result after the same source
    -- has already switched to character B.
    data = player(src)
    if not data or data.citizenid ~= citizenid then return nil, 'character changed while jobs were loading' end

    local decoded = {}
    if row and type(row.jobs) == 'string' then
        local ok, value = pcall(json.decode, row.jobs)
        if ok and type(value) == 'table' then decoded = value end
    end
    local jobs = normalize(decoded)
    local active = data.job or {}
    local current = jobRecord(active.name, active.grade and active.grade.level)
    if current then jobs[current.name] = current end
    local fallback = jobRecord('unemployed', 1)
    if fallback then jobs.unemployed = fallback end
    rosterBySource[src] = { citizenid = citizenid, name = playerName(data), jobs = jobs }
    if not save(src) then
        rosterBySource[src] = nil
        return nil, 'could not save roster'
    end
    return jobs
end

-- Job update events are legacy-compatible and carry a zero-based grade. Read
-- the authoritative player snapshot instead so every assignment path (such as
-- /setjob or another resource calling setJob) stores the correct grade.
saveActiveJob = function(src)
    src = tonumber(src)
    if not src or not schemaReady then return false, 'job storage is still starting' end

    local data = player(src)
    local active = data and data.job
    local current = active and jobRecord(active.name, active.grade and active.grade.level)
    if not data or not data.citizenid or not current then return false, 'character or job is unavailable' end

    local entry = rosterBySource[src]
    if not entry or entry.citizenid ~= data.citizenid then
        -- load() includes the active job before writing a newly loaded roster;
        -- it also prevents a reused source ID from inheriting another roster.
        local roster, err = load(src)
        return roster ~= nil, err
    end

    local saved = entry.jobs[current.name]
    if saved and saved.level == current.level then return true end
    entry.jobs[current.name] = current
    if not save(src) then return false, 'could not save roster' end
    return true
end

local function view(src)
    local roster, err = load(src)
    if not roster then return nil, err end
    local data = player(src)
    local active = data and data.job or {}
    local jobs = {}
    for name, record in pairs(roster) do
        local definition = QB.shared.get('jobs', name)
        local grade = definition and definition.grades[record.level]
        if definition and grade then
            jobs[#jobs + 1] = {
                name = name, label = definition.label or name, level = record.level,
                rank = grade.name or ('Grade ' .. record.level), pay = grade.payment or 0,
                icon = Config.icons[name] or 'BriefcaseBusiness', dutyLocked = Config.disabledDuty[name] == true,
            }
        end
    end
    table.sort(jobs, function(a, b) return a.label < b.label end)
    return { jobs = jobs, active = { name = active.name, onDuty = active.onduty == true } }
end

local function notify(src, type_, message)
    QB.notify.send(src, { title = 'Employment', type = type_, message = message })
end

QB.callback.register('qbmultijob:server:getRoster', function(src)
    return view(src)
end)

QB.callback.register('qbmultijob:server:selectJob', function(src, name)
    if type(name) ~= 'string' then return false, 'invalid job' end
    local roster, err = load(src)
    if not roster then return false, err end
    local record = roster[name]
    if not record then return false, 'that job is not in your roster' end
    local ok, setErr = exports.qbcore:setJob(src, name, record.level)
    if not ok then return false, setErr or 'could not set active job' end
    notify(src, 'success', ('Active job set to %s.'):format((QB.shared.get('jobs', name) or {}).label or name))
    return true, view(src)
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
    local roster, err = load(src)
    if not roster then return false, err end
    local record = jobRecord(name, level)
    if not record then return false, 'unknown job or grade' end
    if not roster[name] then
        local count = 0
        for jobName in pairs(roster) do if jobName ~= 'unemployed' then count = count + 1 end end
        if count >= Config.maxJobs then return false, 'job roster is full' end
    end
    roster[name] = record
    return save(src), 'could not save roster'
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

---Returns every saved employee for a job without requiring callers to resolve
---each citizenid through qbcore or an offline-player lookup.
local function getEmployees(jobName)
    if not schemaReady or not jobRecord(jobName, 1) then return nil, 'unknown job or job storage is still starting' end
    local rows, err = QB.sql.query('SELECT `citizenid`, `name`, `jobs` FROM `qbmultijob_jobs`')
    if err then return nil, 'could not load employee roster' end

    local employees = {}
    for _, row in ipairs(rows or {}) do
        local jobs = normalize((function()
            local ok, decoded = pcall(json.decode, row.jobs or '{}')
            return ok and decoded or {}
        end)())
        local record = jobs[jobName]
        if record then
            employees[#employees + 1] = {
                citizenid = row.citizenid,
                name = row.name ~= '' and row.name or 'unknown',
                level = record.level,
            }
        end
    end
    table.sort(employees, function(a, b) return a.name < b.name end)
    return employees
end

local function updateActiveOffline(citizenid, name, level)
    -- qbcore2 provides the real qb-core compatibility Player object under this
    -- identity. Its grade API is zero-based while qbcore2 roster grades are
    -- one-based, hence the conversion here.
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
    if not schemaReady or not record then return false, 'unknown job or grade' end

    local target = exports.qbcore:getPlayerByCitizenId(citizenid)
    if target then
        local roster, err = load(target.source)
        if not roster then return false, err end
        roster[name] = record
        if target.job and target.job.name == name then
            local ok, setErr = exports.qbcore:setJob(target.source, name, record.level)
            if not ok then return false, setErr or 'could not update active job' end
        end
        return save(target.source), 'could not save roster'
    end

    local row, err = QB.sql.single('SELECT `name`, `jobs` FROM `qbmultijob_jobs` WHERE `citizenid` = ?', { citizenid })
    if err then return false, 'could not load employee jobs' end
    local character, characterErr = QB.sql.single('SELECT `name`, `job` FROM `players` WHERE `citizenid` = ? AND `deleted_at` IS NULL', { citizenid })
    if characterErr or not character then return false, 'employee was not found' end
    local jobs = {}
    if row then
        local ok, decoded = pcall(json.decode, row.jobs or '{}')
        jobs = normalize(ok and decoded or {})
    else
        jobs = {}
        local activeOk, active = pcall(json.decode, character.job or '{}')
        local activeRecord = activeOk and active and jobRecord(active.name, active.grade and active.grade.level)
        if activeRecord then jobs[activeRecord.name] = activeRecord end
        local unemployed = jobRecord('unemployed', 1)
        if unemployed then jobs.unemployed = unemployed end
    end
    jobs[name] = record
    if not row then
        local _, writeErr = QB.sql.upsert('qbmultijob_jobs', 'citizenid', {
            { pk = citizenid, cols = { name = character.name or 'unknown', jobs = json.encode(jobs) } },
        })
        if writeErr then return false, writeErr end
        return true
    end
    local activeOk, active = pcall(json.decode, character.job or '{}')
    if activeOk and active and active.name == name then
        local activeOk, activeErr = updateActiveOffline(citizenid, name, record.level)
        if not activeOk then return false, activeErr end
    end
    local _, writeErr = QB.sql.update('UPDATE `qbmultijob_jobs` SET `name` = ?, `jobs` = ? WHERE `citizenid` = ?', { character.name or row.name, json.encode(jobs), citizenid })
    if writeErr then return false, writeErr end
    return true
end

---Removes an employee job using a citizenid. An active job is moved to
---unemployed so firing works for both online and offline characters.
local function removeEmployeeJob(citizenid, name)
    if type(citizenid) ~= 'string' or type(name) ~= 'string' or name == 'unemployed' then return false, 'invalid employee job' end
    if not schemaReady or not jobRecord(name, 1) then return false, 'unknown job or job storage is still starting' end

    local target = exports.qbcore:getPlayerByCitizenId(citizenid)
    if target then
        local roster, err = load(target.source)
        if not roster or not roster[name] then return false, err or 'employee does not have that job' end
        roster[name] = nil
        if target.job and target.job.name == name then
            local ok, setErr = exports.qbcore:setJob(target.source, 'unemployed', 1)
            if not ok then return false, setErr or 'could not clear active job' end
        end
        return save(target.source), 'could not save roster'
    end

    local row, err = QB.sql.single('SELECT `jobs` FROM `qbmultijob_jobs` WHERE `citizenid` = ?', { citizenid })
    if err then return false, 'could not load employee jobs' end
    if not row then return false, 'employee was not found' end
    local ok, jobs = pcall(json.decode, row.jobs or '{}')
    jobs = normalize(ok and jobs or {})
    if not jobs[name] then return false, 'employee does not have that job' end
    jobs[name] = nil
    local character, characterErr = QB.sql.single('SELECT `job` FROM `players` WHERE `citizenid` = ? AND `deleted_at` IS NULL', { citizenid })
    if characterErr or not character then return false, 'employee was not found' end
    local activeOk, active = pcall(json.decode, character.job or '{}')
    if activeOk and active and active.name == name then
        local cleared, clearErr = updateActiveOffline(citizenid, 'unemployed', 1)
        if not cleared then return false, clearErr end
    end
    local _, writeErr = QB.sql.update('UPDATE `qbmultijob_jobs` SET `jobs` = ? WHERE `citizenid` = ?', { json.encode(jobs), citizenid })
    if writeErr then return false, writeErr end
    return true
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
    while not schemaReady do Wait(50) end
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
