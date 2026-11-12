---
title: Troubleshooting
sidebar_position: 10
---

# Troubleshooting

**"kora_sql was not ready; multi-job persistence is unavailable." in the console.** `kora_sql` did not become ready within 60 seconds. Roster operations stay unavailable until the resource is restarted with `kora_sql` running.

**"schema setup failed" or schema warnings.** The table could not be created or updated; check the database user's permissions and the printed message.

**The roster says "Your job roster is unavailable."** The `getRoster` callback returned no table, usually because the character is not loaded or storage is still starting.

**A job cannot be added ("job roster is full").** The character already holds `Config.maxJobs` jobs besides `unemployed`. Raise the limit or have them leave a job.

**"unknown job" or "unknown grade".** The job or one-based grade level does not exist in `kora_core` shared jobs.

**Duty button missing.** The active job is listed in `Config.disabledDuty` (police by default).

**Cannot leave a job.** The active job and `unemployed` cannot be removed; make another job active first.

**Config changes have no effect.** Restart `kora_multijob`.

**A job changed elsewhere is not in the roster.** The roster is updated from `QBCore:Server:OnJobUpdate` and `kora_core:server:playerLoaded`; if another resource edits jobs without those events being emitted, use `addJob` or `invalidate`.
