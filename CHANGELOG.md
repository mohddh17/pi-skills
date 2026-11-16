# Changelog

## v1.0.0 — 2026-11-16

- Package scaffold: `package.json` with `pi.skills = ["./skills"]`, `pi-package` keyword.
- `skills/chunked-writes/SKILL.md` — write large files in verified chunks.
- `scripts/validate-skills.mjs` — name/description rules, duplicates, missing bundled files.
- `scripts/publish.sh` — create repo via GitHub API or `gh`, push main + tags.
- GitHub Actions workflow validating every push and PR.
