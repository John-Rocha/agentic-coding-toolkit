#!/usr/bin/env node

const assert = require('assert');
const fs = require('fs');
const os = require('os');
const path = require('path');
const { spawnSync } = require('child_process');

const repoRoot = path.resolve(__dirname, '..', '..');
const validator = path.join(repoRoot, 'scripts', 'validate-toolkit.js');

function copyRepo(source, target) {
  fs.mkdirSync(target, { recursive: true });
  for (const entry of fs.readdirSync(source, { withFileTypes: true })) {
    if (entry.name === '.git') continue;
    const sourcePath = path.join(source, entry.name);
    const targetPath = path.join(target, entry.name);
    if (entry.isDirectory()) {
      copyRepo(sourcePath, targetPath);
    } else if (entry.isSymbolicLink()) {
      fs.symlinkSync(fs.readlinkSync(sourcePath), targetPath);
    } else {
      fs.copyFileSync(sourcePath, targetPath);
      fs.chmodSync(targetPath, fs.statSync(sourcePath).mode);
    }
  }
}

function runValidator(cwd) {
  return spawnSync(process.execPath, [validator], {
    cwd,
    encoding: 'utf8',
  });
}

function withFixture(name, mutate) {
  const fixture = fs.mkdtempSync(path.join(os.tmpdir(), `act-lite-validator-${name}-`));
  copyRepo(repoRoot, fixture);
  if (mutate) mutate(fixture);
  return fixture;
}

function assertPasses(name, mutate) {
  const fixture = withFixture(name, mutate);
  const result = runValidator(fixture);
  assert.strictEqual(result.status, 0, `${name} failed unexpectedly:\n${result.stdout}\n${result.stderr}`);
}

function assertFails(name, expected, mutate) {
  const fixture = withFixture(name, mutate);
  const result = runValidator(fixture);
  assert.notStrictEqual(result.status, 0, `${name} passed unexpectedly`);
  const output = `${result.stdout}\n${result.stderr}`;
  assert.match(output, expected, `${name} did not report ${expected}:\n${output}`);
}

assertPasses('clean');

assertFails('missing-skill', /missing required skill directory: skills\/act-implement\//, (fixture) => {
  fs.rmSync(path.join(fixture, 'skills', 'act-implement'), { recursive: true, force: true });
});

assertFails('disallowed-directory', /disallowed Lite package surface present: agents\//, (fixture) => {
  fs.mkdirSync(path.join(fixture, 'agents'));
});

assertFails('version-mismatch', /does not match VERSION/, (fixture) => {
  const manifestPath = path.join(fixture, '.cursor-plugin', 'plugin.json');
  const manifest = JSON.parse(fs.readFileSync(manifestPath, 'utf8'));
  manifest.version = '0.0.0';
  fs.writeFileSync(manifestPath, `${JSON.stringify(manifest, null, 2)}\n`);
});

assertFails('invalid-front-matter', /skill missing valid front matter/, (fixture) => {
  const skillPath = path.join(fixture, 'skills', 'act-update', 'SKILL.md');
  fs.writeFileSync(skillPath, fs.readFileSync(skillPath, 'utf8').replace('---\n', 'name: broken\n'));
});

assertFails('broken-link', /broken link target/, (fixture) => {
  const skillPath = path.join(fixture, 'skills', 'act-update', 'SKILL.md');
  fs.appendFileSync(skillPath, '\n[Broken](./references/missing.md)\n');
});

assertFails('broken-script-reference', /missing script reference/, (fixture) => {
  const skillPath = path.join(fixture, 'skills', 'act-update', 'SKILL.md');
  fs.appendFileSync(skillPath, '\nRun `./scripts/missing.sh`.\n');
});

assertFails('non-executable-shell-script', /script not executable: scripts\/install.sh/, (fixture) => {
  fs.chmodSync(path.join(fixture, 'scripts', 'install.sh'), 0o644);
});

const validatorSource = fs.readFileSync(validator, 'utf8');
assert(!validatorSource.includes('--pro-root'), 'validator must not expose --pro-root');
assert(!/hash comparison|compare.*hash|pro hash/i.test(validatorSource), 'validator must not include Pro hash comparison mode');

console.log('OK: validate-toolkit focused tests passed');
