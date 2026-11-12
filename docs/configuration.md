---
title: Configuration
sidebar_position: 6
---

# Configuration

All options live in `config.lua`. The values are also registered with `kora_lib`'s config system (`Kora.config`) so they can be edited through it when available. Every option description there says to restart `kora_multijob` to apply saved changes.

| Option | Default | Meaning |
| --- | --- | --- |
| `Config.maxJobs` | `4` | Maximum saved jobs per character, not counting `unemployed`. Minimum `0`. Lowering it blocks new additions but does not remove saved jobs. |
| `Config.command` | `'multijob'` | Chat command (no leading slash) that opens the roster; also the key mapping name. |
| `Config.keybind` | `'J'` | Default keyboard key. Players' own rebinding in FiveM settings is kept. |
| `Config.disabledDuty` | `{ police = true }` | Map of job name to `true` that blocks duty toggling from the roster. |
| `Config.icons` | see below | Map of job name to an icon name sent to the roster UI. |

## Duty lock

For a job listed in `Config.disabledDuty`:

- the client does not show the duty button and shows "Duty: Managed by job" on the active job card;
- the server callback `kora_multijob:server:toggleDuty` also refuses ("duty changes are disabled for this job").

Only `disabledDuty.police` is registered with `Kora.config` as an editable option. Other job names added to the table in `config.lua` are still honoured by the code.

## Icons

Defaults: `unemployed = 'BriefcaseBusiness'`, `police = 'Shield'`, `ambulance = 'HeartPulse'`, `mechanic = 'Wrench'`, `tow = 'Truck'`, `taxi = 'Car'`, `lawyer = 'Scale'`, `realestateagent = 'House'`, `government = 'Landmark'`, `news = 'Newspaper'`. Jobs without an entry use `BriefcaseBusiness`. Only the ten listed keys are registered with `Kora.config`.

## Limit semantics

The limit is enforced only by `addJob` (used by `/givejob` and the `addJob` export). Jobs that enter the roster automatically (the active job being synced) and `setEmployeeJob` do not check it. The UI description reads "N of M jobs saved" with M equal to `Config.maxJobs + 1`, because `unemployed` is counted in the displayed total.

## Text

User-visible strings are hardcoded in English in `client.lua` and `server.lua`; the resource has no locale files.
