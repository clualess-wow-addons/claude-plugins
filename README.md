# wow-classic-dev

A [Claude Code](https://claude.com/claude-code) plugin with skills for World of Warcraft Classic Era development — addon development, CurseForge publishing, and WeakAuras — from the [clualess-wow-addons](https://github.com/clualess-wow-addons) org.

## Install

```
/plugin marketplace add clualess-wow-addons/claude-plugins
/plugin install wow-classic-dev@clualess-wow-addons
```

## Skills

| Skill | Description |
|---|---|
| [`wow-classic-addon-development`](skills/wow-classic-addon-development) | Expert reference for building, debugging, and optimizing WoW Classic Era (1.15.x) Lua addons — API availability, taint/combat lockdown, events, Ace3, SavedVariables, TOC files, and 16 deep-dive reference docs. |
| [`wow-classic-addon-publishing`](skills/wow-classic-addon-publishing) | CurseForge publishing end to end — first-time project submission, tag-driven CI/CD via the BigWigs packager (workflow template included), shipping updates, and debugging releases that silently didn't publish. |
| [`wow-classic-addon-repair`](skills/wow-classic-addon-repair) | Triage and repair of third-party addons broken by client patches — cascade-vs-root-cause analysis of error dumps, verifying symbols against the live client source, the 1.15.8 removed-API replacement map, embedded-library traps, and seven generalized case studies. |
| [`wow-classic-weakauras-development`](skills/wow-classic-weakauras-development) | WeakAuras development for Classic Era — custom triggers/TSU contracts, aura_env and the sandbox, Era/SoD/Hardcore targeting, and worked patterns decoded from the top wago.io classic auras. |
| [`wow-classic-weakauras-publishing`](skills/wow-classic-weakauras-publishing) | Publishing WeakAuras on wago.io — export/import strings, versioning, the Companion update pipeline, settings-preserving updates, update-safe pack architecture, and the wago data API for inspecting any aura's code. |
