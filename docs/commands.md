---
title: Commands and permissions
sidebar_position: 4
---

# Commands and permissions

## Player command

| Command | Key | Effect |
| --- | --- | --- |
| `/multijob` (`Config.command`) | `J` (`Config.keybind`, key mapping description "Open job roster") | Opens the Employment app. Ignored while the app is already being opened. |

## Admin commands

Registered through `Kora.commands.add`. Each handler checks permission itself: the console (source `0`) is allowed, players need `kora_core`'s `admin` permission (`exports.kora_core:hasPermission(src, 'admin')`). Others see "You do not have permission for this command."

| Command | Arguments | Effect |
| --- | --- | --- |
| `/givejob` | `[player id] [job] [grade]` | Adds or updates the job in the target's roster (target must be online; the grade is the one-based `kora_core` grade level). Fails if the job or grade is unknown, or if the roster is full (`Config.maxJobs`) and the job is new. Notifies the target on success. |
| `/removejob` | `[player id] [job]` | Removes a job from the online target's roster. Refuses `unemployed` and the target's current active job. |

Replies are shown through `Kora.notify` with the title "Employment".

Note: a grade of `0` is treated as `1` for compatibility with older QB jobs.

## ACE

The resource defines no ACE entries of its own. Admin checks go through `kora_core`'s permission system.
