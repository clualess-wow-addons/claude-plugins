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
| [`wow-classic-weakauras-development`](skills/wow-classic-weakauras-development) | WeakAuras development for Classic Era — custom triggers/TSU contracts, aura_env and the sandbox, Era/SoD/Hardcore targeting, worked patterns decoded from the top wago.io classic auras, and wago.io publishing/Companion mechanics. |
