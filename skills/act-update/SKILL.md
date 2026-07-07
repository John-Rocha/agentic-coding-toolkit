---
name: act-update
description: Update Agentic Coding Toolkit Lite to the latest version
tools: [Bash, Read, AskUserQuestion]
---

<objective>
Check for Agentic Coding Toolkit Lite updates from GitHub, show what changed, and update if the user confirms.

Provides a safe update experience by checking for uncommitted changes,
showing changelog entries before updating, and giving explicit
post-update refresh commands for detected supported tools.
</objective>

<process>

<step name="check_installation">
Verify ACT Lite is installed in the expected location:

```bash
ls ~/.agentic-coding-toolkit-lite/.git 2>/dev/null
```

**If directory doesn't exist or isn't a git repo:**
```
## ACT Lite Update

ACT Lite is not installed in the expected location (`~/.agentic-coding-toolkit-lite`).

To fix this, clone the repository:

    git clone https://github.com/CodeWithAndreaPro/agentic-coding-toolkit-lite.git ~/.agentic-coding-toolkit-lite

Then run the install script:

    # Claude Code
    cd ~/.agentic-coding-toolkit-lite && ./scripts/install.sh --tool claude

    # OpenCode
    cd ~/.agentic-coding-toolkit-lite && ./scripts/install.sh --tool opencode

    # Cursor
    cd ~/.agentic-coding-toolkit-lite && ./scripts/install.sh --tool cursor

    # Codex
    cd ~/.agentic-coding-toolkit-lite && ./scripts/install.sh --tool codex
```

STOP here if not properly installed.
</step>

<step name="check_branch">
Verify ACT Lite is on the main branch:

```bash
cd ~/.agentic-coding-toolkit-lite && git branch --show-current
```

**If not on main:**
```
## ACT Lite Update

You are on branch `<branch_name>`, not `main`.

Please switch to main before updating:

    cd ~/.agentic-coding-toolkit-lite && git checkout main
```

STOP here if not on main branch.
</step>

<step name="check_uncommitted_changes">
Check for uncommitted changes:

```bash
cd ~/.agentic-coding-toolkit-lite && git status --porcelain
```

**If there are uncommitted changes:**
```
## ACT Lite Update

You have uncommitted changes in the ACT Lite directory:

<list of changed files>

Please commit or stash your changes before updating:

    cd ~/.agentic-coding-toolkit-lite
    git stash        # to temporarily save changes
    # or
    git checkout .   # to discard changes
```

STOP here if there are uncommitted changes.
</step>

<step name="get_local_version">
Read the local installed version from the ACT Lite checkout:

```bash
cat ~/.agentic-coding-toolkit-lite/VERSION 2>/dev/null
```

**If VERSION file missing:**
Treat as version `0.0.0` and proceed (older installation without version tracking).
</step>

<step name="fetch_remote">
Fetch the latest from the Lite origin without merging:

```bash
cd ~/.agentic-coding-toolkit-lite && git fetch origin main
```

**If fetch fails:**
```
## ACT Lite Update

Couldn't fetch updates (offline or GitHub unavailable).

To update manually when online:

    cd ~/.agentic-coding-toolkit-lite && git pull origin main
```

STOP here if fetch fails.
</step>

<step name="get_remote_version">
Read the remote version from the Lite origin:

```bash
cd ~/.agentic-coding-toolkit-lite && git show origin/main:VERSION 2>/dev/null
```

**If remote VERSION missing:**
```
## ACT Lite Update

The Lite remote repository doesn't have a VERSION file yet.

This may indicate the version tracking feature hasn't been released.
```

STOP here if remote VERSION is missing.
</step>

<step name="compare_versions">
Compare local vs remote versions:

**If local == remote:**
```
## ACT Lite Update

**Installed:** X.Y.Z
**Latest:** X.Y.Z

You're already on the latest ACT Lite version.
```

STOP here if already up to date.

**If local > remote:**
```
## ACT Lite Update

**Installed:** X.Y.Z
**Latest:** A.B.C

Your local ACT Lite version is ahead of the remote. This could mean:
- You have local changes that haven't been pushed
- You're on a development branch

Please verify your ACT Lite installation is correct.
```

STOP here if local is ahead.
</step>

<step name="show_changelog_preview">
**If remote is ahead**, fetch and show what's new BEFORE updating:

1. Get the remote CHANGELOG.md:
   ```bash
   cd ~/.agentic-coding-toolkit-lite && git show origin/main:CHANGELOG.md
   ```

2. Extract entries between the local and remote versions

3. Display preview and ask for confirmation:

```
## ACT Lite Update Available

**Installed:** 0.1.1
**Latest:** 0.2.0

### What's New
------------------------------------------------------------

## [0.2.0] - 2026-01-23

### Added
- New feature X

### Fixed
- Bug fix Y

------------------------------------------------------------
```

Use AskUserQuestion:
- Question: "Proceed with update?"
- Options:
  - "Yes, update now"
  - "No, cancel"

**If user cancels:** STOP here.
</step>

<step name="run_update">
Run the update:

```bash
cd ~/.agentic-coding-toolkit-lite && git pull origin main
```

If pull fails, show error and STOP.
</step>

<step name="post_update_refresh_guidance">
Do not run install scripts automatically.

Reason: installer scripts may prompt interactively for symlink replacement
or stale-link cleanup, and should be user-controlled.

After successful pull, detect likely tooling usage from existing ACT Lite skill installs:

```bash
ls ~/.claude/skills/act-update ~/.config/opencode/skills/act-update ~/.cursor/plugins/local/agentic-coding-toolkit ~/.codex/skills/act-update/SKILL.md ~/.gemini/skills/act-update 2>/dev/null
```

Then provide post-update commands:

- If Claude symlink exists: suggest `cd ~/.agentic-coding-toolkit-lite && ./scripts/install.sh --tool claude`
- If OpenCode symlink exists: suggest `cd ~/.agentic-coding-toolkit-lite && ./scripts/install.sh --tool opencode`
- If Cursor plugin link exists: suggest `cd ~/.agentic-coding-toolkit-lite && ./scripts/install.sh --tool cursor`
- If Codex skill link exists: suggest `cd ~/.agentic-coding-toolkit-lite && ./scripts/install.sh --tool codex`
- If Gemini skill exists: suggest `cd ~/.agentic-coding-toolkit-lite && ./scripts/install.sh --tool gemini`
- If Antigravity skill exists: suggest `cd ~/.agentic-coding-toolkit-lite && ./scripts/install.sh --tool antigravity`
- If Claude and/or OpenCode are found: remind the user to restart those CLI sessions after reinstalling
- If Cursor is found: remind the user to reload or restart Cursor after reinstalling
- If Codex is found: remind the user to restart Codex or refresh `/skills` after reinstalling
- If Gemini is found: remind the user to restart Gemini CLI or refresh skills after reinstalling
- If Antigravity is found: remind the user to restart Antigravity or refresh skills after reinstalling
- If multiple are found: suggest running each relevant install command and include the relevant restart/reload reminder for each detected tool
- If none are found: show all supported options and ask which CLI/editor the user uses
</step>

<step name="display_result">
Format completion message:

```
## ACT Lite Updated: v0.1.1 -> v0.2.0

Next step: refresh ACT Lite for your installed tooling.

Claude Code:
    cd ~/.agentic-coding-toolkit-lite && ./scripts/install.sh --tool claude

OpenCode:
    cd ~/.agentic-coding-toolkit-lite && ./scripts/install.sh --tool opencode

Cursor:
    cd ~/.agentic-coding-toolkit-lite && ./scripts/install.sh --tool cursor

Codex:
    cd ~/.agentic-coding-toolkit-lite && ./scripts/install.sh --tool codex

Gemini:
    cd ~/.agentic-coding-toolkit-lite && ./scripts/install.sh --tool gemini

Antigravity:
    cd ~/.agentic-coding-toolkit-lite && ./scripts/install.sh --tool antigravity

Then restart any affected Claude/OpenCode CLI sessions, reload or restart Cursor if installed, refresh Codex `/skills` or restart Codex if installed, and restart Gemini CLI or Antigravity if installed, to pick up updates.

[View full changelog](https://github.com/CodeWithAndreaPro/agentic-coding-toolkit-lite/blob/main/CHANGELOG.md)
```
</step>

</process>

<success_criteria>
- [ ] Installation location verified
- [ ] Branch is main
- [ ] No uncommitted changes
- [ ] Local VERSION read from ACT Lite checkout
- [ ] Lite remote fetched successfully
- [ ] Remote VERSION read from Lite origin
- [ ] Update skipped if already current
- [ ] Update aborted if local is ahead
- [ ] Changelog fetched and displayed before update
- [ ] User confirmation obtained
- [ ] Git pull executed successfully
- [ ] Post-update refresh commands shown for relevant tooling
- [ ] Restart reminder shown
</success_criteria>
