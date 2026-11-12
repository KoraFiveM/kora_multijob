---
title: kora_multijob
sidebar_position: 1
---

# kora_multijob

`kora_multijob` keeps a saved roster of jobs for each character and lets the player pick which one is their active `kora_core` job. Players open an "Employment" app (`/multijob`, default key `J`) built with `kora_lib`'s NUI app API, where they can make a saved job active, toggle duty, or leave a saved job. `kora_core` stays the only authority for the active job and duty state; this resource only stores the roster and asks `kora_core` to change the job.

The release version is the `version` field in `fxmanifest.lua`.

## Documentation map

- [Installation](./installation.md): dependencies, manifest load order, database schema and startup notes.
- [How to use](./how-to-use.md): roster concepts, lifecycle, the roster panel, admin commands and management from other resources.
- [Commands](./commands.md): `/multijob`, `/givejob`, `/removejob` and permissions.
- [API reference](./api/index.md): server exports overview.
  - [Cross-resource exports](./api/cross-resource-exports.md): `addJob`, `getRoster`, `getEmployees`, `setEmployeeJob`, `removeEmployeeJob`, `invalidate`.
- [Configuration](./configuration.md): `config.lua` options, duty lock, icons and limit semantics.
- [Events and callbacks](./events.md): server callbacks and the events the resource listens to.
- [Database](./database.md): the `kora_multijob_jobs` table and other tables read.
- [User interface](./ui.md): the `kora_lib` Employment app and the unused `web/` project.
- [Troubleshooting](./troubleshooting.md): common console messages and fixes.

## Feature summary

- Per-character roster stored in `kora_multijob_jobs`, capped by `Config.maxJobs` (the `unemployed` fallback does not count).
- A character's current active `kora_core` job is added to the roster automatically when they load or when their job changes.
- Roster UI: current job card, saved jobs list (searchable from four saved jobs), make active, duty toggle, leave job.
- Optional per-job duty lock (`police` by default).
- Admin commands `/givejob` and `/removejob`.
- Server exports for other resources (for example job management) to read and edit rosters, including offline characters.

## Layout

- `fxmanifest.lua`: manifest and dependencies.
- `config.lua`: configuration, registered with `kora_lib` config.
- `schema.lua`: table definition applied through `kora_sql`.
- `server.lua`: roster storage, callbacks, commands, exports.
- `client.lua`: command, key mapping and the NUI app definition.
- `test/` offline Lua smoke tests, `tests/` kora_qa Gherkin scenarios.
- `web/`: a React project that the manifest does not load (see [User interface](./ui.md)).
