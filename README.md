# qbmultijob

`qbmultijob` keeps a character's earned jobs in `qbmultijob_jobs` and lets the
player choose their active qbcore job with `/multijob` (default key: `J`).
qbcore remains the only authority for the active job and duty state.

## Install

Ensure `qblib`, `qbsql`, and `qbcore` before `qbmultijob`. The resource applies
its own `qbmultijob_jobs` migration when qbsql is ready; do not import the old
`multijob.sql` manually.

## Administration

The ACE-gated commands use qbcore's `admin` permission:

- `/givejob [player id] [job] [grade]`
- `/removejob [player id] [job]`

Grades use qbcore's one-based job grade level. Other resources can call
`exports.qbmultijob:addJob(source, jobName, gradeLevel)` or
`exports.qbmultijob:getRoster(source)`.

For management resources, the roster is a server export and includes the
stored display name, so no per-employee online/offline player lookup is needed:

```lua
local employees = exports.qbmultijob:getEmployees('police')
-- { { citizenid = '...', name = 'Jane Doe', level = 2 }, ... }
exports.qbmultijob:setEmployeeJob(citizenid, 'police', 1) -- hire/promote
exports.qbmultijob:removeEmployeeJob(citizenid, 'police') -- fire
```

The management exports accept a citizenid, update online active jobs directly,
and save an offline active job through qbcore's offline Player object when
needed.

## Configuration

Edit `config.lua` to set the roster limit, command/key binding, duty-locked
roles, and optional icon names. The searchable roster is rendered by qblib's
compact AppShell, so focus, responsive layout, and the shared theme stay
consistent with the other administrative interfaces.
