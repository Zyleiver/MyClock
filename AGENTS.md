# MyClock Codex Integration

This repository drives a local macOS clock that displays Codex task state. When working in this repository, keep the clock status file current through `scripts/codex-clock-status`.

## Status Updates

Run one of these commands from the repository root when the task state changes:

```bash
scripts/codex-clock-status running "Short description of the current task"
scripts/codex-clock-status waiting "Waiting for user input"
scripts/codex-clock-status completed "Short completion summary"
```

Use `blocked` only when progress is genuinely blocked by an external dependency or missing user decision.

## Verification

Before claiming application changes are done, run:

```bash
scripts/smoke-test.sh
```

If GUI behavior changed, also open `build/MyClock.app` and inspect the window.
