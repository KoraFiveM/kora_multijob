---@diagnostic disable: redundant-parameter
local playerJobs = {}
local saveActiveJob

QB.sql.query([[
CREATE TABLE IF NOT EXISTS 
    `qbmultijob_jobs`
    ( 
    `citizenid` VARCHAR(64) NOT NULL,
    `name` VARCHAR(128) NOT NULL DEFAULT 'unknown',
    `jobs` LONGTEXT NOT NULL,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`citizenid`) );
]])

local function player(src)
    return type(src) == 'number' and exports.qbcore:getPlayerData(src)
        or type(src) == 'string' and exports['qb-core']:GetPlayerByCitizenid(src)
        or nil
end

local function citizenIdOf(src)
    if type(src) == 'string' then return src end
    local data = player(src)
    return data and data.citizenid or nil
end

local function jobRecord(name, level)
    level = tonumber(level)
    if level == 0 then level = 1 end
    local job = QB.shared.get('jobs', name)
    if not job then return nil, 'unknown job' end
    local grade = job.grades and job.grades[level]
    if not grade then return nil, 'unknown grade' end
    return { name = name, level = level, gradeLabel = grade.name, jobLabel = job.label, pay = grade.payment }
end

local function playerName(src)
    local pData = player(src)
    if not pData then return 'unknown' end
    return string.format('%s %s', pData.charinfo.firstname or '', pData.charinfo.lastname or '')
end

local function save(src)
    local citizenid = citizenIdOf(src)
    if not citizenid then return false, 'could not resolve citizenid' end
    local entry = playerJobs[citizenid]
    if not entry then return false, 'no roster entry found' end
    QB.sql.query('UPDATE `qbmultijob_jobs` SET `jobs` = ? WHERE `citizenid` = ?', { json.encode(entry), citizenid })
    return true
end

local function load(src)
    local citizenid
    if type(src) == 'string' then
        citizenid = src
    else
        local data = player(src)
        citizenid = data and data.citizenid
    end
    if not citizenid then return nil, 'character not loaded' end

    if playerJobs[citizenid] then return playerJobs[citizenid] end

    local row = QB.sql.single('SELECT `name`, `jobs` FROM `qbmultijob_jobs` WHERE `citizenid` = ?', { citizenid })
    if row then
        playerJobs[citizenid] = json.decode(row.jobs)
        return playerJobs[citizenid]
    end

    local data = player(src)
    if not data then return nil, 'no roster on file and character is not online to create one' end

    playerJobs[citizenid] = { ['unemployed'] = jobRecord('unemployed', 1) }
    if data.job and data.job.name and data.job.name ~= 'unemployed' then
        local record = jobRecord(data.job.name, data.job.grade and data.job.grade.level)
        if record then playerJobs[citizenid][data.job.name] = record end
    end

    QB.sql.insert('INSERT INTO `qbmultijob_jobs` (`citizenid`, `name`, `jobs`) VALUES (?, ?, ?)',
        { citizenid, playerName(src), json.encode(playerJobs[citizenid]) })

    return playerJobs[citizenid]
end

saveActiveJob = function(src)
    local data = player(src)
    local active = data and data.job
    if not active then return false, 'no active job found' end

    local citizenid = data.citizenid
    if not playerJobs[citizenid] then load(src) end
    if not playerJobs[citizenid] then return false, 'could not load roster' end

    local record, err = jobRecord(active.name, active.grade and active.grade.level)
    if not record then return false, err end

    playerJobs[citizenid][active.name] = record
    save(citizenid)
    return true
end

local function view(src)
    local citizenid = citizenIdOf(src)
    if citizenid and not playerJobs[citizenid] then load(src) end

    local data = player(src)
    local active = data and data.job or {}
    local jobs = {}
    for name, record in pairs((citizenid and playerJobs[citizenid]) or {}) do
        local definition = QB.shared.get('jobs', name)
        if definition then
            record.icon = Config.icons[name] or 'BriefcaseBusiness'
            record.dutyLocked = Config.disabledDuty[name] == true
            jobs[#jobs + 1] = record
        end
    end
    table.sort(jobs, function(a, b) return a.pay > b.pay end)
    return { jobs = jobs, active = { name = active.name, onDuty = active.onduty == true } }
end

local function notify(src, type_, message)
    QB.notify.send(src, { title = 'Employment', type = type_, message = message })
end

QB.callback.register('qbmultijob:server:getRoster', function(src)
    return view(src)
end)

QB.callback.register('qbmultijob:server:selectJob', function(src, name)
    assert(src, 'source is required')
    assert(name, 'job name is required')
    assert(QB.shared.get('jobs', name), 'invalid job name')

    local citizenid = citizenIdOf(src)
    if not citizenid then return false, 'character not loaded' end
    if not playerJobs[citizenid] then load(src) end

    local record = playerJobs[citizenid] and playerJobs[citizenid][name]
    if not record then return false, 'that job is not in your roster' end

    if exports.qbcore:setJob(src, name, record.level) then
        notify(src, 'success', ('Active job set to %s.'):format((QB.shared.get('jobs', name) or {}).label or name))
        return true, view(src)
    end
    return false, 'could not set active job'
end)

QB.callback.register('qbmultijob:server:toggleDuty', function(src)
    assert(src, 'source is required')
    local data = player(src)
    local job = data and data.job
    assert(job, 'no active job found')
    if Config.disabledDuty[job.name] then return false, 'duty changes are disabled for this job' end
    local ok, err = exports.qbcore:setJobDuty(src, not job.onduty)
    assert(ok, err or 'could not change duty status')
    return true, view(src)
end)

QB.callback.register('qbmultijob:server:quitJob', function(src, name)
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

local function canManage(src) return src == 0 or exports.qbcore:hasPermission(src, 'admin') end

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
    local ok = save(citizenid)
    if not ok then return false, 'could not save roster' end
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
    local citizenid = citizenIdOf(src)
    if citizenid then playerJobs[citizenid] = nil end
    return true
end

local function getEmployees(jobName)
	local path = ('$."%s"'):format(jobName)
	local result = QB.sql.query([[
		SELECT
			name,
			citizenid,
			JSON_UNQUOTE(JSON_EXTRACT(jobs, CONCAT(?, '.jobLabel'))) AS jobLabel,
			CONCAT(?, '') AS jobName,
			CAST(JSON_EXTRACT(jobs, CONCAT(?, '.pay')) AS UNSIGNED) AS pay,
			CAST(JSON_EXTRACT(jobs, CONCAT(?, '.level')) AS UNSIGNED) AS level
		FROM qbmultijob_jobs
		WHERE JSON_CONTAINS_PATH(jobs, 'one', ?)
	]], { path, jobName, path, path, path })

	return result
end

local function applyJobToPlayer(citizenid, name, level)
    local online = exports.qbcore:getPlayerByCitizenId(citizenid)
    if online then
        if not online.Functions.SetJob(name, level - 1) then return false, 'could not update online job' end
        if not online.Functions.Save() then return false, 'could not save online player' end
        return true
    end

    local offline = exports['qb-core']:GetOfflinePlayerByCitizenId(citizenid)
    if not offline then return false, 'could not load player (online or offline)' end
    if not offline.Functions.SetJob(name, level - 1) then return false, 'could not update offline job' end
    if not offline.Functions.Save() then return false, 'could not save offline player' end
    return true
end

local function setEmployeeJob(citizenid, name, level)
    assert(citizenid and name and level, 'invalid arguments')
    assert(type(level) == 'number' and level > 0, 'invalid level')
    assert(type(citizenid) == 'string' and citizenid ~= '', 'invalid citizenid')
    assert(type(name) == 'string' and name ~= '', 'invalid name')
    assert(QB.shared.get('jobs', name), 'invalid job name')

    if not playerJobs[citizenid] then load(citizenid) end
    if not playerJobs[citizenid] then return false, 'could not load roster' end

    local record, recErr = jobRecord(name, level)
    if not record then return false, recErr end

    if not playerJobs[citizenid][name] then
        return addJob(citizenid, name, level)
    end

    local ok, err = applyJobToPlayer(citizenid, name, level)
    if not ok then return false, err end

    playerJobs[citizenid][name] = record
    if not save(citizenid) then return false, 'could not save roster' end
    return true
end

local function removeEmployeeJob(citizenid, name)
    assert(citizenid and name, 'invalid arguments')
    assert(type(citizenid) == 'string' and citizenid ~= '', 'invalid citizenid')
    assert(type(name) == 'string' and name ~= '', 'invalid name')
    assert(name ~= 'unemployed', 'cannot remove unemployed job')

    if not playerJobs[citizenid] then load(citizenid) end
    if not playerJobs[citizenid] then return false, 'could not load roster' end
    if not playerJobs[citizenid][name] then return false, 'employee does not have that job' end

    playerJobs[citizenid][name] = nil

    local target = exports.qbcore:getPlayerByCitizenId(citizenid) or exports['qb-core']:GetOfflinePlayerByCitizenId(citizenid)
    if target and target.job and target.job.name == name then
        applyJobToPlayer(citizenid, 'unemployed', 1)
    end

    return save(citizenid)
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
AddEventHandler('playerDropped', function() invalidate(tonumber(source)) end)

CreateThread(function()
    for _, src in ipairs(exports.qbcore:getPlayers()) do saveActiveJob(src) end
end)

exports('addJob', addJob)
exports('getRoster', function(src) return view(src) end)
exports('getEmployees', getEmployees)
exports('setEmployeeJob', setEmployeeJob)
exports('removeEmployeeJob', removeEmployeeJob)
exports('invalidate', invalidate)