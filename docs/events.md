---
title: Events and callbacks
sidebar_position: 7
---

# Events and callbacks

## Server callbacks

Registered with `Kora.callback.register` and used by the client UI.

| Callback | Arguments | Returns |
| --- | --- | --- |
| `kora_multijob:server:getRoster` | none | The roster view (see [API reference](./api/cross-resource-exports.md), `getRoster`). |
| `kora_multijob:server:selectJob` | job name | `true, roster` after `kora_core` `setJob` with the stored grade, else `false, reason`. Job must be in the roster. |
| `kora_multijob:server:toggleDuty` | none | `true, roster` after `setJobDuty`, else `false, reason`. Refused for jobs in `Config.disabledDuty`. |
| `kora_multijob:server:quitJob` | job name | `true, roster`, else `false, reason`. Refuses `unemployed`, jobs not in the roster, and the active job. Notifies "Job removed from your roster." |

## Events listened to (server)

| Event | Behaviour |
| --- | --- |
| `kora_core:server:playerLoaded` | Invalidates the cache, then saves the character's active job into the roster (creating the roster if needed). |
| `QBCore:Server:OnJobUpdate` | Saves the new active job and grade into the roster. Errors are printed. |
| `QBCore:Server:OnPlayerUnload` | Invalidates the cached roster. |
| `playerDropped` | Invalidates the cached roster. |

On resource start every online player's active job is saved into their roster.

## Events emitted

None. The resource triggers no network or local events of its own. The client uses the `kora_lib` app actions `multijob:select`, `multijob:duty` and `multijob:quit` internally.
