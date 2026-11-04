# kora_multijob

`kora_multijob` keeps a character's earned jobs in `kora_multijob_jobs` and lets the
player choose their active kora_core job with `/multijob` (default key: `J`).
kora_core remains the only authority for the active job and duty state.

## Install

Ensure `kora_lib`, `kora_sql`, and `kora_core` before `kora_multijob`. The resource applies
its `kora_multijob_jobs` table (declared in `schema.lua`) when kora_sql is ready; do not import
the old `multijob.sql` manually.

## Administration

The ACE-gated commands use kora_core's `admin` permission:

- `/givejob [player id] [job] [grade]`
- `/removejob [player id] [job]`

Grades use kora_core's one-based job grade level. Other resources can call
`exports.kora_multijob:addJob(source, jobName, gradeLevel)` or
`exports.kora_multijob:getRoster(source)`.

For management resources, the roster is a server export and includes the
stored display name, so no per-employee online/offline player lookup is needed:

```lua
local employees = exports.kora_multijob:getEmployees('police')
-- { { citizenid = '...', name = 'Jane Doe', level = 2 }, ... }
exports.kora_multijob:setEmployeeJob(citizenid, 'police', 1) -- hire/promote
exports.kora_multijob:removeEmployeeJob(citizenid, 'police') -- fire
```

The management exports accept a citizenid, update online active jobs directly,
and save an offline active job through kora_core's offline Player object when
needed.

## Configuration

Edit `config.lua` to set the roster limit, command/key binding, duty-locked
roles, and optional icon names. The searchable roster is rendered by kora_lib's
compact AppShell, so focus, responsive layout, and the shared theme stay
consistent with the other administrative interfaces.
