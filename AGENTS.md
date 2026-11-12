# kora_multijob agent guide

`kora_multijob` is a Kora resource that stores a saved multi-job roster per character (`kora_multijob_jobs`) and lets players pick their active `kora_core` job through a `kora_lib` NUI app (`/multijob`, key `J`). Layout: `fxmanifest.lua`, `config.lua` (options, registered with `Kora.config`), `schema.lua` (table definition), `server.lua` (storage, callbacks, commands, exports), `client.lua` (command, key mapping, app definition), `test/` (offline Lua tests), `tests/` (kora_qa feature files) and `web/` (unused React project).

## Documentation

User-facing documentation lives in `docs/` (Markdown, published via the Kora Docusaurus site, kora_docs_next). Read `docs/index.md` first for an overview of features, configuration, commands, exports, events and database usage.

When you add, change, or remove a feature, config option, command, export, event, item, permission, or database table/column, update the matching page in `docs/` in the same change. Keep docs accurate to the code; do not document behaviour that does not exist.

Docs rules: plain Markdown with `title`/`sidebar_position` front matter (no `id`/`slug`), relative links only between docs pages, assets inside `docs/`, fenced code blocks with a language, and no raw `<`, `>`, `{`, `}` outside code (pages are parsed as MDX). The release version comes from `fxmanifest.lua`'s `version` field.
