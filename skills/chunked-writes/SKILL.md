---
name: chunked-writes
description: Writes large files and large feature work in small verified chunks instead of one giant response, so a model with a low max-output-token limit can still finish a big project. Use when a file would exceed a few hundred lines, when output gets truncated or ends mid-function, when a project has many files, or when the user mentions small context/output limits, token limits, truncation, or "continue where you left off".
---

# Chunked writes

Goal: never attempt an artifact bigger than one response can emit. Keep state on
disk, keep each turn small, verify every chunk before writing the next.

## Rules

1. **Plan on disk first.** Write `PLAN.md` with one checkbox per chunk, each chunk
   ≤ 400 lines, and the exact command that verifies it. Re-read it every turn —
   it survives compaction, the conversation may not.
2. **Write sequentially, never in parallel.** Chunk 1 with `write`, chunks 2..N
   appended. Never rewrite the whole file because one chunk was wrong.
3. **Verify after each chunk**, not at the end:
   - TS/JS: `npx tsc --noEmit`, `node --check file.js`
   - Python: `python3 -m py_compile file.py`
   - Markdown/HTML: check the page renders and tags balance
   - Go/Rust: `go build ./...`, `cargo check`
   If the chunk does not parse, fix that chunk before appending the next.
4. **Append safely.** Prefer a heredoc with a quoted delimiter so `$`, backticks and
   `!` are literal:
   ```bash
   cat >> src/big.ts <<'TSEOF'
   ...chunk...
   TSEOF
   ```
   Never append with an unquoted heredoc — shell expansion silently corrupts code.
5. **End each chunk at a clean boundary** (end of function, end of block), and start
   the next one with a one-line comment naming what it adds. That makes resumption
   after truncation obvious.
6. **Resume, do not restart.** If output stops mid-file: `tail -20 <file>`, read the
   last complete construct, then continue from there. Do not re-emit earlier chunks.
7. **Surgical edits only.** Once a chunk exists, change it with `edit` and a small
   `oldText`. Full-file rewrites are how token limits turn into data loss.
8. **Learn the limit.** If a chunk silently stops at roughly the same size, that is
   the output cap; make the next chunk half that size.

## Chunk sizing

| Artifact | Chunk |
|---|---|
| Single source file | 250–400 lines |
| Config / manifest | whole file, one turn |
| Documentation page | one `<section>` or one `<h2>` per turn |
| Multi-file feature | one file per turn, bottom-up: types → core → glue → CLI → tests |
| Generated data (fixtures, seeds, migrations) | a generator script, then run it |

## Anti-patterns

- One `write` for a 2000-line file — truncates and loses the tail.
- Appending without verifying — one broken chunk poisons every later append.
- Restarting the file "to be safe" — burns the budget and loses passed checks.
- Holding the plan only in chat — compaction or a new session erases it.
