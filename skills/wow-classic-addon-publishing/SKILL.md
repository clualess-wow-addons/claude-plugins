---
name: wow-classic-addon-publishing
description: Use when publishing or releasing a WoW addon to CurseForge — first-time project submission, setting up automated GitHub Actions releases (BigWigs packager), shipping an update, adopting CI/CD for an already-published addon, or debugging a green release run that produced no new version on CurseForge or GitHub.
---

# WoW Classic Addon Publishing

## Overview

Releases are **tag-driven**: `git tag vX.Y.Z && git push origin vX.Y.Z` → GitHub Actions → [BigWigs packager](https://github.com/BigWigsMods/packager) → GitHub release + CurseForge upload. The packager is the de-facto community standard; never hand-upload zips once CI is wired.

On each tag the packager: generates a changelog from commits → replaces `@project-version@` in the `.toc` with the tag → derives CurseForge game versions from the `## Interface:` list → zips as `AddonName-vX.Y.Z-classic.zip` → uploads to the CurseForge project ID from the `.toc` → creates a GitHub release with the zip + `release.json`.

## Quick reference

| Fact | Value |
|---|---|
| Workflow template | `references/release-workflow.yml` — copy verbatim |
| GitHub token env var | `GITHUB_OAUTH` (NOT `GITHUB_TOKEN` — wrong name = silent no-op) |
| Workflow permissions | `permissions: contents: write` (new repos default read-only) |
| CurseForge auth | Author token from https://legacy.curseforge.com/account/api-tokens (instant) as secret `CF_API_KEY` — org-level with visibility "all" covers every repo |
| Wrong API to avoid | "CurseForge for Studios" (docs.curseforge.com) — consumer browse API, multi-day approval, cannot publish |
| Upload target | `## X-Curse-Project-ID: <numeric id>` in the `.toc` (missing = upload silently skipped) |
| Version substitution | `## Version: @project-version@` in the `.toc` |
| Game versions | Derived from `## Interface: 11500, ..., 11509` list — keep current or CurseForge tags the release as an old game version |

## Greenfield: first-time publication

1. Addon repo with `AddonName.toc` (PascalCase folder = toc = repo name; `@project-version@` token; Interface list). For addon structure, use the `wow-classic-addon-development` skill.
2. Push to GitHub: `git init -b main && git add . && git commit -m "Initial commit"` then `gh repo create <org>/<Addon> --public --source=. --remote=origin --push`. Ensure the org/repo has the `CF_API_KEY` secret (`gh secret set CF_API_KEY --org <org> --visibility all`).
3. **Manual first submission** at https://authors.curseforge.com/#/projects/create/choose-game → World of Warcraft → game version Classic Era → category → paste README as description. Moderator review takes a few hours to ~24h.
4. After approval, copy the numeric **Project ID** from the project edit URL into `## X-Curse-Project-ID:`.
5. Add `.github/workflows/release.yml` from `references/release-workflow.yml`.
6. `git tag v0.1.0 && git push origin v0.1.0`. Verify (below). Subsequent releases are step 6 only.

## Brownfield

**Shipping an update (CI already wired):** commit, bump the `## Interface:` list if a new client patch shipped, tag, push tag, verify.

**Adopting CI for an addon already published manually:** the CurseForge project exists, so skip the submission step — put the addon in a GitHub repo first if it isn't (greenfield step 2), add `X-Curse-Project-ID` (from the project edit URL) and `@project-version@` to the `.toc`, confirm `CF_API_KEY` is visible to the repo, add the workflow file, tag. The packager attaches new files to the existing project; old manually-uploaded files are untouched.

## Verify every release

```bash
gh run list --repo <org>/<Addon> --limit 1          # workflow ran on the tag?
gh run view <run-id> --repo <org>/<Addon> --log | grep -iE "curse|upload"
# want: "Uploading AddonName-vX.Y.Z-classic.zip (…) … Success!"
gh release view vX.Y.Z --repo <org>/<Addon> --json assets
```

**A green run does NOT mean published.** The packager exits 0 even when it skipped everything — only the log lines prove uploads happened.

## Debugging: green run, no new version

Check in this order:

| Symptom in logs | Cause | Fix |
|---|---|---|
| Upload said `Success!` but addon page shows old version | CurseForge approval/scan queue (minutes–hours; the **most common** case when CI is already proven) | Wait; watch status at authors.curseforge.com → project → Files. Still absent after ~24h or marked Rejected: the Files tab shows the reason; fix and re-tag |
| No CurseForge upload line at all | Missing `X-Curse-Project-ID` in `.toc`, or `CF_API_KEY` not visible to repo | Add ID / fix secret visibility |
| Packaged but no GitHub release | Env var named `GITHUB_TOKEN` instead of `GITHUB_OAUTH` | Rename the env key |
| Release creation denied | Missing `permissions: contents: write` | Add the permissions block |
| Run triggered but wasn't the tag | Tag never pushed or doesn't match `tags:` patterns | `git ls-remote --tags origin`; check run's ref |
| Version in-game shows `@project-version@` | Running a git checkout, not the packaged zip | Install the zip from the release |
| Upload rejected: unknown game version | `## Interface:` build CurseForge doesn't know yet | Drop the too-new build from the list until CurseForge adds it |
