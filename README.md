# pi-skills

Reusable [Pi](https://pi.dev) agent skills, packaged so any machine can install them
from git or npm with one command.

Status: **package scaffold + 1 skill.** Add your own under `skills/<name>/SKILL.md`
and drop the ones you do not want to publish.

## Install on any machine

```bash
# pinned to a tag (recommended)
pi install git:github.com/<owner>/pi-skills@v1.0.0

# or track the default branch
pi install git:github.com/<owner>/pi-skills

# or from npm, once published
pi install npm:pi-skills
```

Then:

```bash
pi list                     # shows installed packages
pi update --extensions      # reconcile git checkouts to newer refs
pi remove git:github.com/<owner>/pi-skills
```

Skills load lazily: only `name` + `description` enter the system prompt, the body is
read when a task matches. Force one with `/skill:name`.

## Add a skill

```bash
mkdir -p skills/my-skill
# write skills/my-skill/SKILL.md with:
#   ---
#   name: my-skill
#   description: What it does AND when to use it (this is the routing text).
#   ---
#   # instructions...
```

Optional bundled files: `scripts/`, `references/`, `assets/` inside the skill dir.
Reference them from `SKILL.md` relative to the skill directory.

Then:

```bash
npm run validate     # name/description rules, duplicate names, missing bundled files
git add -A && git commit -m "add my-skill" && git tag -a v1.1.0 -m "v1.1.0"
git push origin main --tags
```

## Import a skill you already have locally

Copy it (the repo stays independent of `~/.pi/agent/skills`):

```bash
cp -r ~/.pi/agent/skills/<name> skills/<name>
npm run validate
```

Do **not** symlink into `skills/`: git stores symlinks as links, and a clone on
another machine gets a dangling path.

## Layout

```text
pi-skills/
├── package.json          # "pi" manifest: skills: ["./skills"]
├── skills/
│   └── chunked-writes/
│       └── SKILL.md
├── scripts/
│   ├── validate-skills.mjs
│   └── publish.sh
├── .github/workflows/validate.yml
└── README.md
```

## Publish to GitHub

```bash
# 1. identity (once per machine)
git config --global user.name  "Your Name"
git config --global user.email "you@example.com"

# 2a. with a token — creates the repo, pushes main + tags
GITHUB_TOKEN=ghp_xxx ./scripts/publish.sh <owner>/pi-skills

# 2b. with the gh CLI
gh repo create <owner>/pi-skills --public --source=. --push

# 2c. fully manual
#    create an empty repo at https://github.com/new (no README, no .gitignore)
git remote add origin git@github.com:<owner>/pi-skills.git
git push -u origin main --tags
```

Then verify the connection from another machine:

```bash
git ls-remote git@github.com:<owner>/pi-skills.git | head
pi install git:github.com/<owner>/pi-skills@v1.0.0
```

## Notes / gotchas

- `private: true` in `package.json` stops an accidental `npm publish`. Remove it if
  you actually want it on npm; keep the `pi-package` keyword for gallery discovery.
- Tags are what make installs reproducible: `@v1.0.0` pins, a bare branch floats.
- Project-local skills (`<repo>/.pi/skills/`) load only after project trust is
  granted; a package install is user-level and needs no trust prompt.
- Keep descriptions distinct. Two skills with the same description make routing a
  coin flip — `npm run validate` warns about it.

## License

MIT
