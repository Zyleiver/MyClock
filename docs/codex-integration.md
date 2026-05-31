# Codex Integration

MyClock reads Codex state from a local bridge file:

```text
~/.codex-clock/status.json
```

The file is intentionally simple so any Codex thread, shell script, or future automation can update it without requiring a private API.

## Status Schema

```json
{
  "status": "running",
  "task": "Implementing MyClock",
  "updatedAt": "2026-05-31T14:13:59+08:00"
}
```

Supported status values:

- `running`: Codex is actively working.
- `waiting` or `waiting_for_user`: Codex is waiting for user input.
- `completed`, `complete`, or `done`: The task is complete.
- `blocked`: Codex cannot continue without an external change.
- `unknown`: No current status is available.

## Updating Status

Use the helper command from the repository root:

```bash
scripts/codex-clock-status running "Building the macOS app"
scripts/codex-clock-status waiting "Waiting for GitHub repository creation"
scripts/codex-clock-status completed "MVP built and committed"
```

The macOS app polls this file every two seconds.

## Repository-Level Codex Behavior

`AGENTS.md` tells Codex to update this bridge while working inside the repository. This gives the clock a practical connection to the current project without relying on an unavailable Codex desktop API.
