---
title: "Installation"
sidebar_position: 2
---


# Installation

Kora Multijob keeps a per-character roster of every job a player has earned, stored independently of kora_core's single "active job", and lets the player switch which saved job is active from an in-game panel (`/multijob`, default key `J`). It still answers to the legacy export/resource name `kora_multijob`.

## Install Kora Multijob

1. **Add the folder** — Place `kora_multijob` in your resources directory (on the Kora recipe it is `resources/[kora]/kora_multijob`).

2. **Start its dependencies first** — It declares `dependency` on `kora_theme`, `kora_lib`, `kora_sql` and `kora_core`. Start all four — and `kora_sql` specifically before `ensure kora_multijob` — since the schema is created the moment `kora_sql` reports ready.

   ```bash title="server.cfg"
   ensure kora_theme
   ensure kora_lib
   ensure kora_sql
   ensure kora_core
   ensure kora_multijob
   ```

3. **Manifest load order** — Shared scripts load `@kora_lib/init.lua` then `@kora_core/init.lua` then `config.lua`. Server scripts load `@kora_sql/init.lua`, then `schema.lua` (the table declaration), then `server.lua`.

   ```lua title="fxmanifest.lua" {17,18,19,20,24,25,26}
   fx_version 'cerulean'
   game 'gta5'
   lua54 'yes'

   name 'kora_multijob'

   dependency 'kora_theme'
   dependency 'kora_lib'
   dependency 'kora_sql'
   dependency 'kora_core'

   shared_scripts {
       '@kora_lib/init.lua',
       '@kora_core/init.lua',
       'config.lua',
   }

   server_scripts {
       '@kora_sql/init.lua',
       'schema.lua',
       'server.lua',
   }

   client_script 'client.lua'
   ```

## Database schema

The schema (`schema.lua`, applied by `Kora.sql.ensureTables(KoraMultijobSchema)` once `Kora.sql.ready(60000)` resolves) creates a single table. Nothing here needs to be created by hand, and the README explicitly says not to import an old `multijob.sql` file manually.

- `kora_multijob_jobs` — one row per character: `citizenid` (primary key, varchar 64), `name` (varchar 128, default `'unknown'`, the character's display name at last save), `jobs` (longtext JSON object keyed by job name), `updated_at` (timestamp, auto-updated).

## Additional notes

- `kora_multijob` also needs `kora_core`'s shared `jobs` data to contain every job you offer in the roster, with the grades you assign (grade levels are one-based; a stored grade `0` is read as `1`).
- When `kora_sql` is ready (it waits up to 60 seconds) the resource creates or updates `kora_multijob_jobs` from `schema.lua`. If `kora_sql` is not ready in time the console prints "kora_sql was not ready; multi-job persistence is unavailable." and roster operations stay unavailable until the resource is restarted. See [Database](./database.md) and [Troubleshooting](./troubleshooting.md).
- Characters that are online when the resource starts get a roster created from their current job.
- The server also listens to the legacy event names `QBCore:Server:OnPlayerUnload` and `QBCore:Server:OnJobUpdate`, which `kora_core` is expected to emit. See [Events and callbacks](./events.md).
- Options are described in [Configuration](./configuration.md).
