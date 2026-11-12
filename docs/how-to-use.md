---
title: "How to use"
sidebar_position: 3
---


# How to use

Kora Multijob never decides what a character's active job IS — `kora_core` remains the only authority for the active job and duty state. This resource only remembers which jobs a character has earned, and lets the player (or an admin, or another resource) move which one of those saved jobs kora_core currently has active.

## Roster concepts

- A **roster** is `playerJobs[citizenid]`, a table keyed by job name, each value a re-derived `jobRecord`: `{ name, level, gradeLabel, jobLabel, pay }`. The whole record is saved in the `jobs` JSON, but only `name` and `level` are read back; `gradeLabel`, `jobLabel` and `pay` are recomputed from `Kora.shared.get('jobs', name)` every time a roster is read, so a grade's label or pay rate stays correct even if a job definition changes after the roster row was saved.
- A character always has `unemployed` in their roster — it is seeded the first time their roster is created and is the one job `quitJob`/`removejob` refuse to remove.
- `jobRecord(name, level)` is the single validator: it looks the job up in `Kora.shared.get('jobs', name)`, requires that `level` grade to exist, and treats a stored `level` of `0` as `1` for backwards compatibility with pre-Kora qb-job data. A job or grade that no longer exists is silently dropped by `normalize()` rather than surfacing a broken entry.
- `playerJobs` and `sourceCitizenids` are both pure in-memory caches, invalidated on `QBCore:Server:OnPlayerUnload`, `playerDropped`, and repopulated on `kora_core:server:playerLoaded`. A full resource/server restart clears them entirely — `load()` falls back to the database row (or builds a fresh roster for a currently-online character with no row yet) the next time anything needs it.

## Roster lifecycle: load, job changes, resource (re)start

- **On character load** (`kora_core:server:playerLoaded`): the cache is invalidated for that source, then `saveActiveJob(src)` folds the character's current kora_core active job into their roster (creating the roster row itself if none existed) — so a character who already had an active job before kora_multijob was installed is captured without any migration step.
- **On every active-job change** (`QBCore:Server:OnJobUpdate`): `saveActiveJob(src)` re-reads the player's current job/grade and upserts it into their roster. If this fails for an expected startup reason (`'job storage is still starting'` or `'character or job is unavailable'`) it is silent; any other failure is printed to console.
- **On resource start**: a `CreateThread` calls `saveActiveJob(src)` for every currently-connected player (`exports.kora_core:getPlayers()`), so a `/apply-fix`-style restart of this one resource does not lose anyone's in-progress active job.

## Opening the roster panel

The client registers one chat/keybind command, `Config.command` (default `multijob`, default key `J`). `openMenu()` guards against double-opening with an `appActive` flag, fetches the roster via `Kora.callback.trigger('kora_multijob:server:getRoster')`, and renders it as a `kora_lib` AppShell app (`kora_multijob:roster`). A failed fetch (roster not a table) notifies the player and never opens the panel.

```lua title="client.lua"
RegisterCommand(Config.command, openMenu, false)
RegisterKeyMapping(Config.command, 'Open job roster', 'keyboard', Config.keybind)
```

## Selecting, duty, and quitting a saved job

All three player actions are server callbacks the roster panel's `onAction` wires to buttons (`multijob:select`, `multijob:duty`, `multijob:quit`); each returns the full refreshed `view(src)` on success so the panel re-renders from one round trip.

```lua title="server.lua"
-- Player-facing callbacks (client.lua calls these through Kora.callback.trigger)
Kora.callback.register('kora_multijob:server:getRoster', view)
Kora.callback.register('kora_multijob:server:selectJob', function(src, name) ... end)
Kora.callback.register('kora_multijob:server:toggleDuty', function(src) ... end)
Kora.callback.register('kora_multijob:server:quitJob', function(src, name) ... end)
```

- `selectJob(src, name)` — the job must already be in the caller's roster; on success it calls `exports.kora_core:setJob(src, name, record.level)`.
- `toggleDuty(src)` — flips the CURRENT active job's duty via `exports.kora_core:setJobDuty`, refused outright with `'duty changes are disabled for this job'` when `Config.disabledDuty[job.name]` is `true` (default: `police`).
- `quitJob(src, name)` — removes a saved job from the roster. Refused for `'unemployed'`, for a job not in the roster, and for whichever job is currently active (`'choose another active job before removing this one'`) — a player can never quit the job kora_core currently has them working.

## Admin commands: /givejob and /removejob

Both are gated by `canManage(src)` — `src == 0` (server console) or `exports.kora_core:hasPermission(src, 'admin')` — checked inside the handler, not by ACE-restricting the command registration itself (`Kora.commands.add` is called with `restricted = false`). See the Commands section below for exact usage.

## Managing a character's jobs from another resource

For management resources (a boss menu, an HR system, …) the roster is a server export and already includes the stored display name, so no per-employee online/offline player lookup is needed on the caller's side.

```text title="any server script"
local employees = exports.kora_multijob:getEmployees('police')
-- { { citizenid = 'ABC123', name = 'Jane Doe', level = 2 }, ... }

local ok, err = exports.kora_multijob:setEmployeeJob('ABC123', 'police', 1) -- hire/promote
local ok2, err2 = exports.kora_multijob:removeEmployeeJob('ABC123', 'police') -- fire
```

- `setEmployeeJob`/`removeEmployeeJob` accept a `citizenid` (not a source) and work for both online and offline characters: an online target is updated live through `exports.kora_core:setJob`/`getPlayerByCitizenId`; an offline target is read/written straight from the `kora_multijob_jobs` and `players` tables and applied through `exports.kora_core:setOfflineJob`.
- **Current (verified) return behavior**: both functions return `true` only once the roster change has actually been persisted, and `false, <reason>` for every failure path — including when the final `save(citizenid)` call itself fails. Earlier in this resource's history a failed save in part of this flow could still report success; that is not the case in the code read for this page — every return in `setEmployeeJob` and `removeEmployeeJob` is driven by the real outcome of `save()`/`applyJobToPlayer()`, never a hard-coded `true`.
- `Config.maxJobs` (default 4, excluding the `unemployed` fallback) is enforced in `addJob` — the export underlying `/givejob` — not in `setEmployeeJob`, which has no cap of its own and is intended for deliberate hire/promote actions from trusted management code.

## Config.disabledDuty and Config.icons

Both are plain lookup tables read by server.lua (`view`, `toggleDuty`) and client.lua (`appDefinition`). `Config.disabledDuty[jobName] = true` blocks duty toggling for that job from this panel only (duty can still be changed by other resources); `Config.icons[jobName]` is a lucide icon name shown next to that job in the panel, falling back to `'BriefcaseBusiness'` for an unlisted job.
