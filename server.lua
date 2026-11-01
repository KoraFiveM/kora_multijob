local playerJobs = {}
local sourceCitizenids = {}
local schemaReady = false

CreateThread(function()
    local ready = Kora.sql.ready(60000)
    if not ready then
        print('^1[qbmultijob]^7 qbsql was not ready; multi-job persistence is unavailable.')
        return
    end
    local _, err = Kora.sql.migrateFiles(GetCurrentResourceName(), {
        { version = 1, name = 'jobs', file = 'sql/001_jobs.sql' },
    })
    if err then
        print(('^1[qbmultijob]^7 migration failed: %s'):format(err))
        return
    end
    schemaReady = true
end)

local function player(src)
    if type(src) ~= 'number' then return nil end
    return exports.kora_core:getPlayerData(src)
end

local function citizenIdOf(src)
    if type(src) == 'string' then return src end
    local data = player(src)
    return data and data.citizenid or nil
end

local function jobRecord(name, level)
    level = tonumber(level)

    if level == 0 then -- allows backwards compat of old qb jobs
        level = 1
    end

    local job = Kora.shared.get('jobs', name)
    if not job then return nil, 'unknown job' end

    local grade = job.grades and job.grades[level]
    if not grade then return nil, 'unknown grade' end

    return { name = name, level = level, gradeLabel = grade.name, jobLabel = job.label, pay = grade.payment }
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

local function save(citizenid, name)
    local jobs = playerJobs[citizenid]
    if not jobs then return false, 'no roster entry found' end
    local cols = { jobs = json.encode(jobs) }
    if type(name) == 'string' and name ~= '' then cols.name = name end
    local _, err = Kora.sql.upsert('qbmultijob_jobs', 'citizenid', {
        { pk = citizenid, cols = cols },
    })
    return not err
end

local function load(src)
    if not schemaReady then return nil, 'job storage is still starting' end

    local citizenid
    if type(src) == 'string' then
        citizenid = src
    else
        local data = player(src)
        citizenid = data and data.citizenid
        if citizenid then sourceCitizenids[src] = citizenid end
    end
    if not citizenid then return nil, 'could not resolve citizenid' end
    if playerJobs[citizenid] then return playerJobs[citizenid] end

    local row, err = Kora.sql.single('SELECT `name`, `jobs` FROM `qbmultijob_jobs` WHERE `citizenid` = ?', { citizenid })
    if err then return nil, 'could not load saved jobs' end
    if row then
        local ok, decoded = pcall(json.decode, row.jobs or '{}')
        playerJobs[citizenid] = normalize(ok and decoded or {})
        return playerJobs[citizenid]
    end

    if type(src) == 'string' then return nil, 'no roster on file for this character' end
    local data = player(src)
    if not data then return nil, 'no roster on file and character is not online to create one' end

    playerJobs[citizenid] = { unemployed = jobRecord('unemployed', 1) }
    if data.job and data.job.name and data.job.name ~= 'unemployed' then
        local record = jobRecord(data.job.name, data.job.grade and data.job.grade.level)
        if record then playerJobs[citizenid][data.job.name] = record end
    end

    if not save(citizenid, playerName(data)) then
        playerJobs[citizenid] = nil
        return nil, 'could not save roster'
    end
    return playerJobs[citizenid]
end

local function saveActiveJob(src)
    local data = player(src)
    local active = data and data.job
    if not active then return false, 'no active job found' end

    local citizenid = data.citizenid
    if not playerJobs[citizenid] then
        local roster, err = load(src)
        return roster ~= nil, err
    end

    local record, err = jobRecord(active.name, active.grade and active.grade.level)
    if not record then return false, err end

    playerJobs[citizenid][active.name] = record
    return save(citizenid)
end

local function view(src)
    local citizenid = citizenIdOf(src)
    if citizenid and not playerJobs[citizenid] then load(src) end

    local data = player(src)
    local active = data and data.job or {}
    local jobs = {}
    for name, record in pairs((citizenid and playerJobs[citizenid]) or {}) do
        local current = jobRecord(name, record.level)
        if current then
            current.icon = Config.icons[name] or 'BriefcaseBusiness'
            current.dutyLocked = Config.disabledDuty[name] == true
            jobs[#jobs + 1] = current
        end
    end
    table.sort(jobs, function(a, b) return a.pay > b.pay end)
    return { jobs = jobs, active = { name = active.name, onDuty = active.onduty == true } }
end

local function notify(src, type_, message)
    Kora.notify.send(src, { title = 'Employment', type = type_, message = message })
end

Kora.callback.register('qbmultijob:server:getRoster', view)

Kora.callback.register('qbmultijob:server:selectJob', function(src, name)
    if type(name) ~= 'string' then return false, 'invalid job' end

    local citizenid = citizenIdOf(src)
    if not citizenid then return false, 'character not loaded' end
    if not playerJobs[citizenid] then load(src) end

    local record = playerJobs[citizenid] and playerJobs[citizenid][name]
    if not record then return false, 'that job is not in your roster' end

    if exports.kora_core:setJob(src, name, record.level) then
        notify(src, 'success', ('Active job set to %s.'):format((Kora.shared.get('jobs', name) or {}).label or name))
        return true, view(src)
    end

    return false, 'could not set active job'
end)

Kora.callback.register('qbmultijob:server:toggleDuty', function(src)
    local data = player(src)
    local job = data and data.job
    if not job then return false, 'character not loaded' end
    if Config.disabledDuty[job.name] then return false, 'duty changes are disabled for this job' end
    local ok, err = exports.kora_core:setJobDuty(src, not job.onduty)
    if not ok then return false, err or 'could not change duty status' end
    return true, view(src)
end)

Kora.callback.register('qbmultijob:server:quitJob', function(src, name)
    if type(name) ~= 'string' or name == 'unemployed' then return false, 'that job cannot be removed' end

    local data = player(src)
    local jobData = data and data.job
    local citizenid = citizenIdOf(src)
    if not citizenid then return false, 'character not loaded' end

    local roster = playerJobs[citizenid] or load(src)
    if not roster or not roster[name] then return false, 'that job is not in your roster' end
    if jobData and jobData.name == name then return false, 'choose another active job before removing this one' end

    roster[name] = nil
    if not save(citizenid) then return false, 'could not save your roster' end
    notify(src, 'info', 'Job removed from your roster.')
    return true, view(src)
end)

local function canManage(src) return src == 0 or exports.kora_core:hasPermission(src, 'admin') end

local function addJob(src, name, level)
    local citizenid = citizenIdOf(src)
    if not citizenid then return false, 'could not resolve citizenid' end

    local roster = playerJobs[citizenid]
    if not roster then
        local err
        roster, err = load(src)
        if not roster then return false, err end
    end

    local record, recErr = jobRecord(name, level)
    if not record then return false, recErr end

    if not roster[name] then
        local count = 0
        for jobName in pairs(roster) do if jobName ~= 'unemployed' then count = count + 1 end end
        if count >= Config.maxJobs then return false, 'job roster is full' end
    end

    roster[name] = record
    if not save(citizenid) then return false, 'could not save roster' end
    return true
end

for _, command in ipairs({
    { name = 'givejob', help = 'Add or update a player job', handler = function(src, args)
        local target, level = tonumber(args[1]), tonumber(args[3])
        if not target or not args[2] or not level or not exports.kora_core:getPlayerData(target) then return notify(src, 'error', 'Usage: /givejob [id] [job] [grade]') end
        local ok, err = addJob(target, args[2], level)
        notify(src, ok and 'success' or 'error', ok and 'Job saved.' or err)
        if ok then notify(target, 'success', 'A job was added to your roster.') end
    end },
    { name = 'removejob', help = 'Remove a player job', handler = function(src, args)
        local target, name = tonumber(args[1]), args[2]
        if not target or not name then return notify(src, 'error', 'Usage: /removejob [id] [job]') end
        local roster = load(target)
        if not roster or not roster[name] or name == 'unemployed' then return notify(src, 'error', 'Player does not have that removable job.') end
        if exports.kora_core:getPlayerData(target, { 'job', 'name' }) == name then return notify(src, 'error', 'Player must change active job first.') end
        roster[name] = nil
        local ok = save(target)
        notify(src, ok and 'success' or 'error', ok and 'Job removed.' or 'Could not save roster.')
    end },
}) do
    Kora.commands.add(command.name, command.help, nil, false, function(src, args)
        if not canManage(src) then return notify(src, 'error', 'You do not have permission for this command.') end
        command.handler(src, args)
    end)
end

local function invalidate(src)
    local citizenid = sourceCitizenids[src] or citizenIdOf(src)
    sourceCitizenids[src] = nil
    if citizenid then playerJobs[citizenid] = nil end
    return true
end

local function getEmployees(jobName)
    if not schemaReady or not jobRecord(jobName, 1) then return nil, 'unknown job or job storage is still starting' end
    local rows, err = Kora.sql.query('SELECT `citizenid`, `name`, `jobs` FROM `qbmultijob_jobs`')
    if err then return nil, 'could not load employee roster' end

    local employees = {}
    for _, row in ipairs(rows or {}) do
        local ok, decoded = pcall(json.decode, row.jobs or '{}')
        local record = normalize(ok and decoded or {})[jobName]
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

local function applyJobToPlayer(citizenid, name, level)
    local online = exports.kora_core:getPlayerByCitizenId(citizenid)
    if online then
        return exports.kora_core:setJob(online.source, name, level)
    end

    return exports.kora_core:setOfflineJob(citizenid, name, level)
end

local function setEmployeeJob(citizenid, name, level)
    local record, recErr = jobRecord(name, level)
    if not record then return false, recErr end
    if type(citizenid) ~= 'string' or citizenid == '' or not schemaReady then return false, 'invalid citizenid or job storage is still starting' end

    local target = exports.kora_core:getPlayerByCitizenId(citizenid)
    if target then
        local roster, err = load(target.source)
        if not roster then return false, err end
        roster[name] = record
        if target.job and target.job.name == name then
            local changed, changeErr = exports.kora_core:setJob(target.source, name, record.level)
            if not changed then return false, changeErr or 'could not update active job' end
        end
        return save(citizenid), 'could not save roster'
    end

    local row, rowErr = Kora.sql.single('SELECT `name`, `jobs` FROM `qbmultijob_jobs` WHERE `citizenid` = ?', { citizenid })
    if rowErr then return false, 'could not load employee jobs' end
    local character, characterErr = Kora.sql.single('SELECT `name`, `job` FROM `players` WHERE `citizenid` = ? AND `deleted_at` IS NULL', { citizenid })
    if characterErr or not character then return false, 'employee was not found' end
    local decoded = {}
    if row then
        local ok, value = pcall(json.decode, row.jobs or '{}')
        if ok then decoded = value end
    end
    local jobs = normalize(decoded)
    jobs[name] = record
    playerJobs[citizenid] = jobs
    local activeOk, active = pcall(json.decode, character.job or '{}')
    if activeOk and active and active.name == name then
        local changed, changeErr = applyJobToPlayer(citizenid, name, record.level)
        if not changed then return false, changeErr end
    end
    local saved, saveErr = save(citizenid, row and nil or character.name)
    playerJobs[citizenid] = nil
    if not saved then return false, saveErr or 'could not save roster' end
    return true
end

local function removeEmployeeJob(citizenid, name)
    if type(citizenid) ~= 'string' or type(name) ~= 'string' or name == 'unemployed' then return false, 'invalid employee job' end
    if not schemaReady or not jobRecord(name, 1) then return false, 'unknown job or job storage is still starting' end

    local target = exports.kora_core:getPlayerByCitizenId(citizenid)
    if target then
        local roster, err = load(target.source)
        if not roster or not roster[name] then return false, err or 'employee does not have that job' end
        roster[name] = nil
        if target.job and target.job.name == name then
            local changed, changeErr = exports.kora_core:setJob(target.source, 'unemployed', 1)
            if not changed then return false, changeErr or 'could not clear active job' end
        end
        return save(citizenid), 'could not save roster'
    end

    local row, rowErr = Kora.sql.single('SELECT `jobs` FROM `qbmultijob_jobs` WHERE `citizenid` = ?', { citizenid })
    if rowErr then return false, 'could not load employee jobs' end
    if not row then return false, 'employee was not found' end
    local ok, decoded = pcall(json.decode, row.jobs or '{}')
    local jobs = normalize(ok and decoded or {})
    if not jobs[name] then return false, 'employee does not have that job' end
    jobs[name] = nil
    local character, characterErr = Kora.sql.single('SELECT `job` FROM `players` WHERE `citizenid` = ? AND `deleted_at` IS NULL', { citizenid })
    if characterErr or not character then return false, 'employee was not found' end
    local activeOk, active = pcall(json.decode, character.job or '{}')
    if activeOk and active and active.name == name then
        local changed, changeErr = applyJobToPlayer(citizenid, 'unemployed', 1)
        if not changed then return false, changeErr end
    end
    playerJobs[citizenid] = jobs
    local saved, saveErr = save(citizenid)
    playerJobs[citizenid] = nil
    return saved, saveErr
end

AddEventHandler('QBCore:Server:OnPlayerUnload', invalidate)
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
AddEventHandler('playerDropped', function() invalidate(tonumber(source)) end)

CreateThread(function()
    for _, src in ipairs(exports.kora_core:getPlayers()) do saveActiveJob(src) end
end)

exports('addJob', addJob)
exports('getRoster', view)
exports('getEmployees', getEmployees)
exports('setEmployeeJob', setEmployeeJob)
exports('removeEmployeeJob', removeEmployeeJob)
exports('invalidate', invalidate)
