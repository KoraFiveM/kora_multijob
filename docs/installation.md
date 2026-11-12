---
title: Installation and dependencies
sidebar_position: 2
---

# Installation and dependencies

## Dependencies

`fxmanifest.lua` declares these dependencies:

- `kora_theme`
- `kora_lib` (shared init script, `Kora.nui`, `Kora.callback`, `Kora.notify`, `Kora.config`)
- `kora_sql` (server init script, `Kora.sql`)
- `kora_core` (shared init script, players, jobs, permissions, commands)

## Steps

1. Ensure `kora_theme`, `kora_lib`, `kora_sql` and `kora_core` before `kora_multijob`.
2. Start `kora_multijob`. No manual SQL import is needed: when `kora_sql` is ready (it waits up to 60 seconds) the resource creates or updates `kora_multijob_jobs` from `schema.lua`. See [Database](./database.md).
3. Jobs offered in the roster must exist in `kora_core`'s shared `jobs` data, with the grade you assign.

Characters that are online when the resource starts get a roster created from their current job.

## Compatibility

The server also listens to the legacy event names `QBCore:Server:OnPlayerUnload` and `QBCore:Server:OnJobUpdate`, which `kora_core` is expected to emit. See [Events and callbacks](./events.md).
