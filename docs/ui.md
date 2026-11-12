---
title: User interface
sidebar_position: 9
---

# User interface

The interface is a `kora_lib` NUI app (id `kora_multijob:roster`, title "Employment", compact layout, placed right, 500 px wide) registered in `client.lua` with `Kora.nui.registerApp` and opened with `Kora.nui.openApp`.

## Content

- Navigation entry "My jobs" with a badge showing the number of saved jobs. The description reads "N of M jobs saved" (M is `Config.maxJobs + 1`).
- **Current job** list: label, grade label, Grade and Pay metadata, an On duty / Off duty badge, and a duty button (hidden and replaced with "Duty: Managed by job" when locked).
- **Saved jobs** list: each job has "Make active" and "Leave job" (with a confirmation). `unemployed` has no leave action. A search box appears when there are four or more saved jobs.
- After each action the roster is refreshed from the server and a notice is shown.

Icons come from `Config.icons`; see [Configuration](./configuration.md).

## The web directory

`web/` contains a React/Vite project (`web/src/App.tsx`, built output in `web/build`) with an older standalone roster UI that posts to `https://kora_multijob/<action>`. `fxmanifest.lua` has no `ui_page` or `files` entry for it and `client.lua` registers no NUI callbacks, so it is not used at runtime. The live UI is the `kora_lib` app above.
