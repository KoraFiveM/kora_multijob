---
title: "Commands"
sidebar_position: 4
---


# Commands

One player-facing client command and two console-style admin commands, all name/keybind-configurable or permission-gated — see each row for exactly how.

## Built-in commands

### `/multijob`

Opens the job roster panel showing the caller's saved jobs and current active job/duty state.

| Field | Details |
| --- | --- |
| Context | In-game · client command (`Config.command`, default key `J` via `RegisterKeyMapping`) |
| Arguments | No arguments. |
| Access | Any player may run it; it only ever shows and acts on the caller's own roster. |

**Example**

```text
/multijob
```

**Result**

Opens the `kora_multijob:roster` NUI app listing saved jobs with "Make active" / duty-toggle / "Leave job" actions as applicable.

### `/givejob [id] [job] [grade]`

Adds or updates a job (and grade) in a player's saved roster via `addJob`, enforcing `Config.maxJobs` for a job not already on the roster. Notifies both the admin and (if online) the target player.

| Field | Details |
| --- | --- |
| Context | Server console or in-game · server command |
| Arguments | id — target player server id. job — job name (must exist in `Kora.shared.get('jobs', ...)`). grade — numeric grade level. |
| Access | Console (`src == 0`) or a player with the `kora_core` `admin` permission (`canManage`). |

**Example**

```text
/givejob 3 police 2
```

**Result**

`Job saved.` to the admin and `A job was added to your roster.` to the target on success; `Usage: /givejob [id] [job] [grade]` or the underlying error otherwise (for example `job roster is full`, `unknown job`, `unknown grade`).

### `/removejob [id] [job]`

Removes a job from a player's saved roster directly (not through the `removeEmployeeJob` export — this path only targets an ONLINE player by server id).

| Field | Details |
| --- | --- |
| Context | Server console or in-game · server command |
| Arguments | id — target player server id. job — job name to remove (cannot be `unemployed`). |
| Access | Console (`src == 0`) or a player with the `kora_core` `admin` permission (`canManage`). |

**Example**

```text
/removejob 3 police
```

**Result**

`Job removed.` on success; `Player does not have that removable job.` if the job is not on the roster (or is `unemployed`); `Player must change active job first.` if it is currently their active job; `Could not save roster.` if persistence fails.

## Permissions and replies

- `/givejob` and `/removejob` are registered through `Kora.commands.add` unrestricted; each handler checks permission itself. The console (source `0`) is allowed, players need `kora_core`'s `admin` permission (`exports.kora_core:hasPermission(src, 'admin')`). Others see "You do not have permission for this command."
- Replies are shown through `Kora.notify` with the title "Employment".
- `/givejob` also prints the usage line when the target id is not an online player.
- A grade of `0` is treated as `1` for compatibility with older QB jobs.
- `/multijob` is ignored while the app is already being opened. Its key mapping description is "Open job roster"; players' own rebinding in FiveM settings is kept.
- The resource defines no ACE entries of its own.

See [Configuration](./configuration.md) for `Config.command`, `Config.keybind` and `Config.maxJobs`.
