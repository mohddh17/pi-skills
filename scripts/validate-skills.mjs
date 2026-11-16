#!/usr/bin/env node
/**
 * Validate every skill in ./skills against the Agent Skills spec rules that
 * Pi enforces (and a few it only warns about).
 *
 * Usage:
 *   node scripts/validate-skills.mjs [skillsDir]
 *
 * Exit codes: 0 = ok (warnings allowed), 1 = errors found.
 * No dependencies on purpose: this must run on a bare node install in CI.
 */

import { readdir, readFile, stat } from "node:fs/promises";
import { join, resolve, basename } from "node:path";

const root = resolve(process.argv[2] ?? "skills");

const NAME_RE = /^[a-z0-9]+(-[a-z0-9]+)*$/;
const NAME_MAX = 64;
const DESC_MAX = 1024;

const errors = [];
const warnings = [];

const err = (skill, msg) => errors.push(`${skill}: ${msg}`);
const warn = (skill, msg) => warnings.push(`${skill}: ${msg}`);

/** Parse the leading `--- ... ---` block into a flat string map. */
function frontmatter(text) {
  if (!text.startsWith("---")) return null;
  const end = text.indexOf("\n---", 3);
  if (end === -1) return null;
  const block = text.slice(3, end);
  const data = {};
  let key = null;
  for (const line of block.split("\n")) {
    if (!line.trim()) continue;
    const m = /^([A-Za-z0-9_-]+):\s*(.*)$/.exec(line);
    if (m) {
      key = m[1];
      data[key] = m[2].trim();
    } else if (key && /^\s+/.test(line)) {
      // simple folded/continuation line
      data[key] = `${data[key]} ${line.trim()}`.trim();
    }
  }
  // strip surrounding quotes
  for (const k of Object.keys(data)) {
    data[k] = data[k].replace(/^["']|["']$/g, "");
  }
  return data;
}

async function main() {
  let entries;
  try {
    entries = await readdir(root, { withFileTypes: true });
  } catch {
    console.error(`error: skills directory not found: ${root}`);
    process.exit(1);
  }

  const dirs = entries.filter((e) => e.isDirectory()).map((e) => e.name).sort();

  if (dirs.length === 0) {
    console.error(`error: no skill directories in ${root}`);
    process.exit(1);
  }

  const seenNames = new Map();
  const seenDescriptions = new Map();
  const rows = [];

  for (const dir of dirs) {
    const file = join(root, dir, "SKILL.md");
    let text;
    try {
      text = await readFile(file, "utf8");
    } catch {
      err(dir, "missing SKILL.md");
      continue;
    }

    const fm = frontmatter(text);
    if (!fm) {
      err(dir, "missing or malformed YAML frontmatter (must start with '---')");
      continue;
    }

    const name = fm.name;
    const description = fm.description;

    if (!name) {
      err(dir, "frontmatter has no 'name'");
    } else {
      if (!NAME_RE.test(name)) {
        err(dir, `name "${name}" must be lowercase letters/digits/hyphens, no leading/trailing/consecutive hyphens`);
      }
      if (name.length > NAME_MAX) {
        err(dir, `name is ${name.length} chars (max ${NAME_MAX})`);
      }
      if (name !== dir) {
        warn(dir, `name "${name}" differs from directory "${basename(dir)}" (Pi allows it, other implementations may not)`);
      }
      if (seenNames.has(name)) {
        err(dir, `duplicate skill name "${name}" (also in ${seenNames.get(name)})`);
      } else {
        seenNames.set(name, dir);
      }
    }

    if (!description) {
      err(dir, "frontmatter has no 'description' (skill will not load)");
    } else {
      if (description.length > DESC_MAX) {
        err(dir, `description is ${description.length} chars (max ${DESC_MAX})`);
      }
      if (description.length < 40) {
        warn(dir, "description is very short; it is the only thing the model sees before loading, say what it does AND when to use it");
      }
      const norm = description.toLowerCase();
      if (seenDescriptions.has(norm)) {
        warn(dir, `identical description to "${seenDescriptions.get(norm)}" — routing between them will be ambiguous`);
      } else {
        seenDescriptions.set(norm, dir);
      }
    }

    const body = text.slice(text.indexOf("\n---", 3) + 4).trim();
    if (!body) warn(dir, "SKILL.md has frontmatter but no instructions body");

    // referenced bundled files that do not exist
    for (const m of body.matchAll(/`((?:\.\/)?(?:scripts|references|assets)\/[^`\s]+)`/g)) {
      const rel = m[1].replace(/^\.\//, "");
      try {
        await stat(join(root, dir, rel));
      } catch {
        warn(dir, `references missing bundled file: ${rel}`);
      }
    }

    rows.push({
      name: name ?? dir,
      descriptionLength: description ? description.length : 0,
      bytes: Buffer.byteLength(text),
    });
  }

  for (const r of rows) {
    console.log(`ok  ${r.name.padEnd(34)} ${String(r.descriptionLength).padStart(4)} desc chars  ${String(r.bytes).padStart(6)} B`);
  }

  if (warnings.length) {
    console.log(`\n${warnings.length} warning(s):`);
    for (const w of warnings) console.log(`  warn  ${w}`);
  }
  if (errors.length) {
    console.log(`\n${errors.length} error(s):`);
    for (const e of errors) console.log(`  error ${e}`);
    process.exit(1);
  }
  console.log(`\n${rows.length} skill(s) valid.`);
}

main();
