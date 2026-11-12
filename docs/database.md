---
title: Database
sidebar_position: 8
---

# Database

The table is declared in `schema.lua` and applied with `Kora.sql.ensureTables` once `kora_sql` is ready. Schema warnings are printed to the server console.

## kora_multijob_jobs

| Column | Type | Notes |
| --- | --- | --- |
| `citizenid` | `varchar(64)` | Primary key. |
| `name` | `varchar(128)` | Character display name, default `unknown`. Set when the roster is created. |
| `jobs` | `longtext` | JSON object keyed by job name: `{ name, level, gradeLabel, jobLabel, pay }`. |
| `updated_at` | `timestamp` | Defaults to the current time and updates on change. |

Stored records are re-validated against `kora_core` shared jobs on every read; entries for unknown jobs or grades are dropped from the in-memory roster. Display labels and pay in the UI come from the current job data, not the stored copy.

## Other tables read

- `players` (owned by `kora_core`): `citizenid`, `name`, `job` and `deleted_at`, read only by `setEmployeeJob` and `removeEmployeeJob` for offline characters. Writes to the active job go through `kora_core`.

Do not import an old `multijob.sql`; the schema is managed automatically.
