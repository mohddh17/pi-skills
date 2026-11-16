#!/usr/bin/env bash
# Create the GitHub repo (if needed) and push main + tags.
#
# Usage:
#   GITHUB_TOKEN=ghp_xxx ./scripts/publish.sh <owner>/<repo> [--private]
#   ./scripts/publish.sh <owner>/<repo>            # uses gh CLI if installed
#
# Idempotent: re-running on an existing repo just pushes.
set -euo pipefail

REPO_SLUG="${1:-}"
VISIBILITY="public"
[[ "${2:-}" == "--private" ]] && VISIBILITY="private"

if [[ -z "$REPO_SLUG" || "$REPO_SLUG" != */* ]]; then
  echo "usage: GITHUB_TOKEN=... $0 <owner>/<repo> [--private]" >&2
  exit 2
fi

cd "$(dirname "$0")/.."

# --- checks ---------------------------------------------------------------
[[ -d .git ]] || { echo "error: not a git repo (run git init first)" >&2; exit 1; }
git rev-parse --verify HEAD >/dev/null 2>&1 || { echo "error: no commits yet" >&2; exit 1; }
npm run --silent validate || { echo "error: skills failed validation" >&2; exit 1; }

if ! git config user.name >/dev/null || ! git config user.email >/dev/null; then
  echo "error: set git identity first:" >&2
  echo "  git config --global user.name  \"Your Name\"" >&2
  echo "  git config --global user.email \"you@example.com\"" >&2
  exit 1
fi

API="https://api.github.com"

create_repo_api() {
  local token="$1"
  local code
  code=$(curl -sS -o /tmp/gh-create.json -w '%{http_code}' \
    -X POST "$API/user/repos" \
    -H "Authorization: Bearer $token" \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    -d "{\"name\":\"${REPO_SLUG#*/}\",\"private\":$([[ $VISIBILITY == private ]] && echo true || echo false),\"description\":\"Reusable Pi agent skills\",\"has_issues\":true,\"has_wiki\":false,\"auto_init\":false}")

  case "$code" in
    201) echo "created $REPO_SLUG ($VISIBILITY)";;
    422) echo "repo $REPO_SLUG already exists — pushing to it";;
    401|403) echo "error: token rejected ($code). Needs 'repo' scope." >&2
             head -c 400 /tmp/gh-create.json >&2; echo >&2; exit 1;;
    *)   echo "error: GitHub API returned $code" >&2
         head -c 400 /tmp/gh-create.json >&2; echo >&2; exit 1;;
  esac
}

if [[ -n "${GITHUB_TOKEN:-}" ]]; then
  create_repo_api "$GITHUB_TOKEN"
  # push over HTTPS with the token, then rewrite the remote to SSH so the
  # credential never sits in .git/config
  git remote remove origin 2>/dev/null || true
  git remote add origin "https://x-access-token:${GITHUB_TOKEN}@github.com/${REPO_SLUG}.git"
  git push -u origin HEAD:main
  git push origin --tags
  git remote set-url origin "git@github.com:${REPO_SLUG}.git"
  echo "origin -> git@github.com:${REPO_SLUG}.git (SSH; token not stored)"
elif command -v gh >/dev/null 2>&1; then
  if gh repo view "$REPO_SLUG" >/dev/null 2>&1; then
    echo "repo exists — pushing"
    git remote remove origin 2>/dev/null || true
    git remote add origin "git@github.com:${REPO_SLUG}.git"
    git push -u origin HEAD:main
    git push origin --tags
  else
    gh repo create "$REPO_SLUG" "--$VISIBILITY" --source=. --remote=origin --push
    git push origin --tags
  fi
else
  echo "error: no GITHUB_TOKEN and no gh CLI." >&2
  echo "  set a token:  GITHUB_TOKEN=ghp_xxx $0 $REPO_SLUG" >&2
  echo "  or install gh: https://cli.github.com" >&2
  echo "  or create the repo at https://github.com/new then:" >&2
  echo "    git remote add origin git@github.com:${REPO_SLUG}.git" >&2
  echo "    git push -u origin main --tags" >&2
  exit 1
fi

echo
echo "done. install it anywhere with:"
echo "  pi install git:github.com/${REPO_SLUG}@$(git describe --tags --abbrev=0 2>/dev/null || echo main)"
