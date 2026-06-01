# MyClock

A small macOS Pomodoro clock that stays above other windows, requires a work goal before starting a focus session, and shows the current Codex task status.

## Features

- 25 minute work timer and 5 minute break timer.
- Floating macOS window with a pin toggle for always-on-top behavior.
- Compact mode that automatically appears after the focus timer starts.
- Work goal validation before the focus timer starts.
- Codex task status panel reading from `~/.codex-clock/status.json`.
- Helper command for Codex or shell scripts to publish status updates.

## Run

```bash
swift run MyClock
```

## Build a macOS app bundle

```bash
chmod +x scripts/build-app.sh scripts/codex-clock-status
scripts/build-app.sh
open build/MyClock.app
```

## Publish Codex status

The app polls `~/.codex-clock/status.json` every two seconds. Update it with:

```bash
scripts/codex-clock-status running "Implementing MyClock"
scripts/codex-clock-status waiting "Waiting for user answer"
scripts/codex-clock-status completed "MyClock MVP complete"
```

Supported statuses are `running`, `waiting`, `waiting_for_user`, `blocked`, `completed`, `complete`, `done`, and `unknown`.

See [Codex integration](docs/codex-integration.md) for the bridge schema and repository-level Codex behavior.

## Verify

```bash
scripts/smoke-test.sh
```

## GitHub

Target owner: `Zyleiver`

Suggested repository name: `MyClock`

With a GitHub token that can create repositories:

```bash
GITHUB_TOKEN=... scripts/github-bootstrap.py
```

This creates the repository, pushes `main`, and creates starter labels, milestone, and issues. See [GitHub management](docs/github-management.md).

Manual fallback:

```bash
git remote set-url origin https://github.com/Zyleiver/MyClock.git
git push -u origin main
```

If the remote repository does not exist yet, create `Zyleiver/MyClock` on GitHub first, then run the push command.
