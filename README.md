# qbmultijob

`qbmultijob` keeps a character's earned jobs in `qbmultijob_jobs` and lets the
player choose their active qbcore job with `/multijob` (default key: `J`).
qbcore remains the only authority for the active job and duty state.

## Install

Ensure `qblib`, `qbsql`, and `qbcore` before `qbmultijob`. The resource applies
its own `qbmultijob_jobs` migration when qbsql is ready; do not import the old
`multijob.sql` manually.

## Administration

The ACE-gated commands use qbcore's `admin` permission:

- `/givejob [player id] [job] [grade]`
- `/removejob [player id] [job]`

Grades use qbcore's one-based job grade level. Other resources can call
`exports.qbmultijob:addJob(source, jobName, gradeLevel)` or
`exports.qbmultijob:getRoster(source)`.

## Configuration

Edit `config.lua` to set the roster limit, command/key binding, duty-locked
roles, and optional icon names. The UI imports qbtheme, so it automatically
follows the shared configured palette.
