---
title: "Cross-resource exports"
sidebar_position: 2
---


# Cross-resource exports

Server-only exports for other resources: reading a roster or its employees by job, and mutating a character's roster (and, where needed, their live active job) by citizenid rather than by online source.

Namespace: `exports.kora_multijob` · Source: `server.lua`

## How it works

`setEmployeeJob`/`removeEmployeeJob` both resolve an ONLINE target through `exports.kora_core:getPlayerByCitizenId(citizenid)` first; only when that lookup is empty do they fall back to reading/writing `kora_multijob_jobs` and the `players` table directly and, if the changed job was the character's active one, apply it through `exports.kora_core:setOfflineJob` via the shared `applyJobToPlayer` helper.

## Terms used on this page

| Term | Meaning |
| --- | --- |
| applyJobToPlayer(citizenid, name, level) | Routes an active-job change to `exports.kora_core:setJob` (player online) or `exports.kora_core:setOfflineJob` (player offline) — the one place `setEmployeeJob`/`removeEmployeeJob` apply a job to a character regardless of connection state. |

## Functions

6 server exports.

### `exports.kora_multijob:addJob(src, name, level)`

Adds or updates a job on an ONLINE player's roster, enforcing `Config.maxJobs` (excluding `unemployed`) for a job not already on the roster. Also the function behind `/givejob`.

**Parameters**

| Name | Type | Description |
| --- | --- | --- |
| `src` | integer | Target player server id. |
| `name` | string | Job name. |
| `level` | integer | Grade level. |

**Returns**

- **ok** — true on success.
- **err** — `'could not resolve citizenid'`, a `load()` error, `jobRecord` validation error (`'unknown job'` / `'unknown grade'`), `'job roster is full'`, or `'could not save roster'`.

**Example**

```lua
local ok, err = exports.kora_multijob:addJob(source, 'police', 1)
```

**Representative console output**

```text
Does not notify or set the job active by itself — it only writes the roster row.
```

### `exports.kora_multijob:getRoster(src)`

Same function registered as the `kora_multijob:server:getRoster` callback, also exposed as a direct export.

**Parameters**

| Name | Type | Description |
| --- | --- | --- |
| `src` | integer |  |

**Returns**

- **`{ jobs: table[], active: { name, onDuty } }`** — see the roster-callbacks module for the exact shape.

**Example**

```lua
local roster = exports.kora_multijob:getRoster(source)
```

**Representative console output**

```text
Equivalent to triggering the callback, without the client round trip.
```

### `exports.kora_multijob:getEmployees(jobName)`

All characters (online or not) who currently hold `jobName` in their saved roster, with their display name and grade — no per-employee online/offline lookup needed by the caller.

**Parameters**

| Name | Type | Description |
| --- | --- | --- |
| `jobName` | string |  |

**Returns**

- **employees** — sorted array of `{ citizenid, name, level }` by name.
- **nil, err** — `'unknown job or job storage is still starting'` for an invalid job name or before the schema is ready, or `'could not load employee roster'` on a query failure.

**Example**

```lua
local employees = exports.kora_multijob:getEmployees('police')
```

**Representative console output**

```text
Scans every row in `kora_multijob_jobs` — intended for a boss menu/HR screen, not a hot path.
```

### `exports.kora_multijob:setEmployeeJob(citizenid, name, level)`

Hires or promotes a character into a job by citizenid, online or offline. See "Managing a character's jobs from another resource" in How to use for the full online/offline flow.

**Parameters**

| Name | Type | Description |
| --- | --- | --- |
| `citizenid` | string |  |
| `name` | string |  |
| `level` | integer |  |

**Returns**

- **ok** — true only once the roster change is persisted.
- **false, err** — `jobRecord` validation error, `'invalid citizenid or job storage is still starting'`, a `load()`/lookup error, `'employee was not found'`, an `exports.kora_core:setJob`/`setOfflineJob` failure reason, or `'could not save roster'`.

**Example**

```lua
local ok, err = exports.kora_multijob:setEmployeeJob('ABC123', 'police', 2)
```

**Representative console output**

```text
Current (fixed) behavior: every branch's return value tracks the real outcome of `save()`/`applyJobToPlayer()` — there is no path that reports `true` while the roster was not actually saved.
```

### `exports.kora_multijob:removeEmployeeJob(citizenid, name)`

Fires a character from a job by citizenid, online or offline; clears their active job to `unemployed` first if that job was active.

**Parameters**

| Name | Type | Description |
| --- | --- | --- |
| `citizenid` | string |  |
| `name` | string | Cannot be `'unemployed'`. |

**Returns**

- **ok** — true only once the roster change is persisted.
- **false, err** — `'invalid employee job'`, `'unknown job or job storage is still starting'`, `'employee does not have that job'`, an `exports.kora_core` job-change failure reason, `'employee was not found'`, or `'could not save roster'`.

**Example**

```lua
local ok, err = exports.kora_multijob:removeEmployeeJob('ABC123', 'police')
```

**Representative console output**

```text
Current (fixed) behavior: the final return is `saved, saveErr` straight from the persistence call — a failed save is never reported as a success.
```

### `exports.kora_multijob:invalidate(src)`

Drops the in-memory roster cache for a source (and its citizenid mapping). Also wired to `QBCore:Server:OnPlayerUnload` and `playerDropped`.

**Parameters**

| Name | Type | Description |
| --- | --- | --- |
| `src` | integer |  |

**Returns**

- **Always returns `true`.**

**Example**

```lua
exports.kora_multijob:invalidate(source)
```

**Representative console output**

```text
Forces the next `getRoster`/`load` for that citizenid to re-read the database row.
```

## Limits and related APIs

`getEmployees` requires the schema to be ready and scans every row in `kora_multijob_jobs` — fine for an admin/boss screen, not meant to be called per-tick. `setEmployeeJob` has no `Config.maxJobs` cap of its own (unlike `addJob`/`/givejob`).

## Additional notes

- `addJob` also accepts a citizenid string in place of `src` (for a character whose roster already exists). It does not change the active job and does not check permissions; callers must authorise.
- `getRoster` creates the roster from the player's current job if none exists. Each job entry has `name`, `level`, `gradeLabel`, `jobLabel`, `pay`, `icon`, `dutyLocked`, sorted by pay descending. `active` is `{ name, onDuty }`.
- `invalidate` is the call to make after editing `kora_multijob_jobs` directly.
- `getEmployees`, `setEmployeeJob` and `removeEmployeeJob` take a citizenid and need the database to be ready.
- `setEmployeeJob` updates the active job too when the job is the character's active one (online via `setJob`, offline via `kora_core`'s `setOfflineJob`); offline characters must exist in `players` and not be deleted. It does not make a different job active.
- `removeEmployeeJob` sets the character to `unemployed` grade 1 when the removed job was active.

The server callbacks used by the UI are listed in [Events and callbacks](../events.md).
