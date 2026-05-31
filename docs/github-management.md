# GitHub Management

The target repository is:

```text
https://github.com/Zyleiver/MyClock
```

## One-Step Bootstrap

If you have a GitHub token with repository permissions, run:

```bash
GITHUB_TOKEN=... scripts/github-bootstrap.py
```

The script will:

- Create `Zyleiver/MyClock` if it does not exist.
- Set `origin` to `https://github.com/Zyleiver/MyClock.git`.
- Push `main`.
- Create labels for app, Codex, Pomodoro, and release work.
- Create an `MVP follow-up` milestone.
- Create issues for menu bar mode, notifications, session history, direct Codex integration, and release signing.

## Manual Fallback

If you prefer to create the repository manually:

1. Create an empty public GitHub repository named `MyClock` under `Zyleiver`.
2. Run:

```bash
git remote set-url origin https://github.com/Zyleiver/MyClock.git
git push -u origin main
```

3. Use the issue list in `scripts/github-bootstrap.py` to create follow-up issues.
