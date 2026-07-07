#!/usr/bin/env node

// ACT Lite static package-boundary validator.
// Fast, conservative checks only: no installer execution and no Pro comparison.

const fs = require('fs');
const path = require('path');

const repoRoot = process.cwd();
const errors = [];
const warnings = [];

const requiredSkills = [
  'act-config',
  'act-update',
  'act-interview',
  'act-create-spec',
  'act-refine-spec',
  'act-create-issues',
  'act-implement',
];

const allowedSkillSet = new Set(requiredSkills);

const requiredFiles = [
  'VERSION',
  '.cursor-plugin/plugin.json',
  'scripts/install.sh',
  'scripts/uninstall.sh',
  'scripts/lib/act-run-script.js',
  'scripts/lib/bootstrap-act-settings.js',
  'scripts/lib/codex.sh',
  'scripts/lib/common.sh',
  'scripts/lib/install-codex.sh',
  'scripts/lib/transform-skill-codex.js',
  'scripts/lib/transform-skill-codex.mjs',
  'scripts/lib/uninstall-codex.sh',
];

const disallowedPaths = [
  'agents',
  'commands',
  'hooks',
  'tools',
  'scripts/tests/run-install-tests.mjs',
  'scripts/lib/act-dart-migrate.js',
  'scripts/lib/install-codex-hooks.js',
  'scripts/lib/transform-agent.js',
];

function exists(filePath) {
  return fs.existsSync(filePath);
}

function rel(filePath) {
  return path.relative(repoRoot, filePath).split(path.sep).join('/');
}

function readFile(filePath) {
  return fs.readFileSync(filePath, 'utf8');
}

function walk(dir, out = []) {
  if (!exists(dir)) return out;
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const filePath = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      walk(filePath, out);
    } else {
      out.push(filePath);
    }
  }
  return out;
}

function isExecutable(filePath) {
  try {
    return (fs.statSync(filePath).mode & 0o111) !== 0;
  } catch {
    return false;
  }
}

function parseFrontMatter(content) {
  if (!content.startsWith('---\n')) return null;
  const end = content.indexOf('\n---\n', 4);
  if (end === -1) return null;

  const raw = content.slice(4, end);
  const values = new Map();
  for (const line of raw.split('\n')) {
    if (!line.trim()) continue;
    const match = line.match(/^([A-Za-z0-9_-]+)\s*:\s*(.*)$/);
    if (!match) {
      return { valid: false, values };
    }
    values.set(match[1], match[2].trim());
  }

  return { valid: true, values };
}

function checkRequiredFiles() {
  for (const relPath of requiredFiles) {
    const filePath = path.resolve(repoRoot, relPath);
    if (!exists(filePath) || !fs.statSync(filePath).isFile()) {
      errors.push(`missing required file: ${relPath}`);
    }
  }
}

function checkRequiredSkills() {
  const skillsDir = path.resolve(repoRoot, 'skills');
  if (!exists(skillsDir) || !fs.statSync(skillsDir).isDirectory()) {
    errors.push('missing required directory: skills/');
    return;
  }

  for (const skillName of requiredSkills) {
    const skillDir = path.join(skillsDir, skillName);
    const skillDoc = path.join(skillDir, 'SKILL.md');
    if (!exists(skillDir) || !fs.statSync(skillDir).isDirectory()) {
      errors.push(`missing required skill directory: skills/${skillName}/`);
    } else if (!exists(skillDoc) || !fs.statSync(skillDoc).isFile()) {
      errors.push(`missing required skill doc: skills/${skillName}/SKILL.md`);
    }
  }

  for (const entry of fs.readdirSync(skillsDir, { withFileTypes: true })) {
    if (entry.isDirectory() && !allowedSkillSet.has(entry.name)) {
      errors.push(`disallowed skill directory present: skills/${entry.name}/`);
    }
  }
}

function checkDisallowedPaths() {
  for (const relPath of disallowedPaths) {
    if (exists(path.resolve(repoRoot, relPath))) {
      errors.push(`disallowed Lite package surface present: ${relPath}${relPath.includes('.') ? '' : '/'}`);
    }
  }
}

function checkCursorPluginManifest() {
  const manifestPath = path.resolve(repoRoot, '.cursor-plugin', 'plugin.json');
  if (!exists(manifestPath)) return;

  let manifest;
  try {
    manifest = JSON.parse(readFile(manifestPath));
  } catch {
    errors.push('invalid JSON: .cursor-plugin/plugin.json');
    return;
  }

  if (manifest.name !== 'agentic-coding-toolkit-lite') {
    errors.push(`Cursor plugin manifest name must be agentic-coding-toolkit-lite (found: ${manifest.name || 'missing'})`);
  }
  if (manifest.skills !== './skills/') {
    errors.push(`Cursor plugin manifest must point to ./skills/ (found: ${manifest.skills || 'missing'})`);
  }
  if (!exists(path.resolve(repoRoot, 'skills'))) {
    errors.push('Cursor plugin manifest skills path missing: ./skills/');
  }

  const versionPath = path.resolve(repoRoot, 'VERSION');
  if (!exists(versionPath)) {
    errors.push('missing required file: VERSION');
    return;
  }

  const version = readFile(versionPath).trim();
  if (!version) {
    errors.push('VERSION must not be empty');
  }
  if (manifest.version !== version) {
    errors.push(`Cursor plugin manifest version (${manifest.version || 'missing'}) does not match VERSION (${version || 'empty'})`);
  }

  for (const forbiddenKey of ['agents', 'commands', 'hooks', 'tools']) {
    if (Object.prototype.hasOwnProperty.call(manifest, forbiddenKey)) {
      errors.push(`Cursor plugin manifest must omit ${forbiddenKey}: .cursor-plugin/plugin.json`);
    }
  }
}

function checkFrontMatter(filePath) {
  const content = readFile(filePath);
  const frontMatter = parseFrontMatter(content);
  if (!frontMatter || !frontMatter.valid) {
    errors.push(`skill missing valid front matter: ${rel(filePath)}`);
    return;
  }

  for (const key of ['name', 'description', 'tools']) {
    if (!frontMatter.values.has(key) || !frontMatter.values.get(key)) {
      errors.push(`skill front matter missing ${key}: ${rel(filePath)}`);
    }
  }

  const expectedName = path.basename(path.dirname(filePath));
  const actualName = frontMatter.values.get('name');
  if (actualName && actualName !== expectedName) {
    errors.push(`skill front matter name mismatch: ${rel(filePath)} (found: ${actualName}, expected: ${expectedName})`);
  }
}

function checkMarkdownLinks(filePath) {
  const dir = path.dirname(filePath);
  const content = readFile(filePath);
  const linkRegex = /\]\((\.\.?\/[^)]+)\)/g;
  let match;

  while ((match = linkRegex.exec(content)) !== null) {
    const target = match[1].trim();
    if (/\{.*\}/.test(target)) continue;
    const pathOnly = target.replace(/#.*$/, '');
    const resolved = path.resolve(dir, pathOnly);
    if (!exists(resolved)) {
      errors.push(`broken link target in ${rel(filePath)}: ${target}`);
    }
  }
}

function checkScriptReferences(filePath) {
  const dir = path.dirname(filePath);
  const content = readFile(filePath);
  const scriptRegex = /\b((?:\.\/)?scripts\/[A-Za-z0-9_./-]+\.sh|skills\/[A-Za-z0-9_-]+\/scripts\/[A-Za-z0-9_./-]+\.(?:js|sh))\b/g;
  let match;

  while ((match = scriptRegex.exec(content)) !== null) {
    const target = match[1].replace(/^\.\//, '');
    const resolvedLocal = path.resolve(dir, target);
    const resolvedRoot = path.resolve(repoRoot, target);
    const resolved = target.startsWith('skills/') ? resolvedRoot : (exists(resolvedLocal) ? resolvedLocal : resolvedRoot);
    if (!exists(resolved)) {
      errors.push(`missing script reference in ${rel(filePath)}: ${match[1]}`);
    }
  }
}

function checkSkillReferences(filePath) {
  const content = readFile(filePath);
  const skillRegex = /Skill\(([^)]+)\)/g;
  let match;

  while ((match = skillRegex.exec(content)) !== null) {
    const skillName = match[1].trim();
    if (!allowedSkillSet.has(skillName) || !exists(path.resolve(repoRoot, 'skills', skillName))) {
      errors.push(`missing or disallowed skill reference in ${rel(filePath)}: Skill(${skillName})`);
    }
  }
}

function checkMarkdownSanity(filePath) {
  const lines = readFile(filePath).split('\n');
  let inFence = false;
  for (const line of lines) {
    if (/^```/.test(line)) inFence = !inFence;
  }
  if (inFence) {
    warnings.push(`unclosed fenced code block: ${rel(filePath)}`);
  }
}

function checkShellScriptsExecutable() {
  for (const filePath of walk(path.resolve(repoRoot, 'scripts')).filter((file) => file.endsWith('.sh'))) {
    if (!isExecutable(filePath)) {
      errors.push(`script not executable: ${rel(filePath)}`);
    }
  }
}

function checkSkillDocs() {
  const skillFiles = walk(path.resolve(repoRoot, 'skills')).filter((file) => file.endsWith('SKILL.md'));

  for (const filePath of skillFiles) {
    checkFrontMatter(filePath);
    checkMarkdownLinks(filePath);
    checkScriptReferences(filePath);
    checkSkillReferences(filePath);
    checkMarkdownSanity(filePath);
  }

  const otherMarkdown = walk(path.resolve(repoRoot, 'skills')).filter((file) => file.endsWith('.md') && !file.endsWith('SKILL.md'));
  for (const filePath of otherMarkdown) {
    checkMarkdownLinks(filePath);
    checkMarkdownSanity(filePath);
  }
}

function main() {
  checkRequiredFiles();
  checkRequiredSkills();
  checkDisallowedPaths();
  checkCursorPluginManifest();
  checkSkillDocs();
  checkShellScriptsExecutable();

  if (warnings.length > 0) {
    console.log('Warnings:');
    for (const warning of warnings) console.log(`- ${warning}`);
    console.log('');
  }

  if (errors.length > 0) {
    console.error('Errors:');
    for (const error of errors) console.error(`- ${error}`);
    process.exit(1);
  }

  console.log('OK: ACT Lite static validation passed');
}

main();
