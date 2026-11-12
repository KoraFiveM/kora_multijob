---
title: Exports
sidebar_position: 5
---

# Exports

All exports are server side. `source` is a player id; `citizenid` is the character's string id.

## Player rosters

### addJob(source, jobName, gradeLevel)

Adds or updates a job in a character's roster. Accepts a player id (or a citizenid string for a character whose roster already exists). Returns `true`, or `false, reason`. Fails for an unknown job/grade, a full roster (`Config.maxJobs`) or a save failure. Does not change the active job and does not check permissions; callers must authorise.

### getRoster(source)

Returns `{ jobs = { ... }, active = { name, onDuty } }`. Each job has `name`, `level`, `gradeLabel`, `jobLabel`, `pay`, `icon`, `dutyLocked`, sorted by pay descending. Creates the roster from the player's current job if none exists.

### invalidate(source)

Drops the cached roster for that player so it is reloaded from the database next time. Always returns `true`. Call it if you edit `kora_multijob_jobs` directly.

## Employee management

These accept a citizenid and work for online and offline characters. They return `false, reason` on failure and need the database to be ready.

```lua
local employees = exports.kora_multijob:getEmployees('police')
-- { { citizenid = '...', name = 'Jane Doe', level = 2 }, ... }

exports.kora_multijob:setEmployeeJob(citizenid, 'police', 1) -- hire / promote
exports.kora_multijob:removeEmployeeJob(citizenid, 'police') -- fire
```

### getEmployees(jobName)

Returns every saved character holding `jobName`, as `{ citizenid, name, level }` sorted by name, or `nil, reason` for an unknown job or while storage is starting. Reads the whole table and decodes each row.

### setEmployeeJob(citizenid, jobName, gradeLevel)

Sets the job and grade in the roster. If that job is the character's active job, the active job is updated too (online via `setJob`, offline via `kora_core`'s `setOfflineJob`). Offline characters must exist in `players` and not be deleted. Does not check `Config.maxJobs`. Does not make a different job active.

### removeEmployeeJob(citizenid, jobName)

Removes the job from the roster. If it was the active job, the character is set to `unemployed` grade 1. Refuses `unemployed`.
