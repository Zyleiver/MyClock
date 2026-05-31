#!/usr/bin/env python3
import json
import os
import subprocess
import sys
import urllib.error
import urllib.request

OWNER = os.environ.get("GITHUB_OWNER", "Zyleiver")
REPO = os.environ.get("GITHUB_REPO", "MyClock")
TOKEN = os.environ.get("GITHUB_TOKEN") or os.environ.get("GH_TOKEN")
API = "https://api.github.com"

LABELS = [
    {"name": "app", "color": "0E8A16", "description": "macOS app behavior"},
    {"name": "codex", "color": "1D76DB", "description": "Codex status bridge"},
    {"name": "pomodoro", "color": "FBCA04", "description": "Pomodoro timer behavior"},
    {"name": "release", "color": "5319E7", "description": "Packaging and distribution"},
]

ISSUES = [
    {
        "title": "Add menu bar mode",
        "labels": ["app"],
        "body": "Let MyClock run from the macOS menu bar while keeping the floating window available.",
    },
    {
        "title": "Add notification center alerts",
        "labels": ["app", "pomodoro"],
        "body": "Notify when a focus session ends and when a break ends.",
    },
    {
        "title": "Add session history export",
        "labels": ["pomodoro"],
        "body": "Persist completed focus sessions with goal text and export the history for review.",
    },
    {
        "title": "Evaluate direct Codex API integration",
        "labels": ["codex"],
        "body": "Replace the local file bridge if a stable local Codex task status API becomes available.",
    },
    {
        "title": "Create signed app release workflow",
        "labels": ["release"],
        "body": "Package, sign, and publish MyClock releases for easier installation on macOS.",
    },
]


def require_token() -> None:
    if not TOKEN:
        print("Set GITHUB_TOKEN or GH_TOKEN before running this script.", file=sys.stderr)
        sys.exit(2)


def request(method: str, path: str, payload: dict | None = None) -> tuple[int, dict | list | None]:
    require_token()
    data = None
    headers = {
        "Accept": "application/vnd.github+json",
        "Authorization": f"Bearer {TOKEN}",
        "Content-Type": "application/json",
        "User-Agent": "MyClock bootstrap",
        "X-GitHub-Api-Version": "2022-11-28",
    }
    if payload is not None:
        data = json.dumps(payload).encode("utf-8")

    req = urllib.request.Request(f"{API}{path}", data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req, timeout=30) as response:
            body = response.read().decode("utf-8")
            return response.status, json.loads(body) if body else None
    except urllib.error.HTTPError as error:
        body = error.read().decode("utf-8")
        try:
            parsed = json.loads(body) if body else None
        except json.JSONDecodeError:
            parsed = {"message": body}
        return error.code, parsed


def repo_exists() -> bool:
    status, _ = request("GET", f"/repos/{OWNER}/{REPO}")
    return status == 200


def authenticated_login() -> str:
    status, body = request("GET", "/user")
    if status == 200 and isinstance(body, dict) and "login" in body:
        return str(body["login"])
    print(f"Could not read authenticated GitHub user: HTTP {status} {body}", file=sys.stderr)
    sys.exit(1)


def create_repo() -> None:
    if repo_exists():
        print(f"Repository already exists: {OWNER}/{REPO}")
        return

    login = authenticated_login()
    create_path = "/user/repos" if OWNER.lower() == login.lower() else f"/orgs/{OWNER}/repos"
    status, body = request(
        "POST",
        create_path,
        {
            "name": REPO,
            "description": "A macOS Pomodoro clock with Codex task status.",
            "private": False,
            "has_issues": True,
            "has_projects": True,
            "auto_init": False,
        },
    )
    if status not in {200, 201}:
        print(f"Could not create repository: HTTP {status} {body}", file=sys.stderr)
        if OWNER.lower() != login.lower():
            print(
                f"Authenticated as {login}; {OWNER} must be an organization you can create repos in.",
                file=sys.stderr,
            )
        sys.exit(1)
    print(f"Created repository: {OWNER}/{REPO}")


def create_label(label: dict) -> None:
    status, _ = request("POST", f"/repos/{OWNER}/{REPO}/labels", label)
    if status == 201:
        print(f"Created label: {label['name']}")
    elif status == 422:
        print(f"Label already exists: {label['name']}")
    else:
        print(f"Label skipped: {label['name']} HTTP {status}")


def create_milestone() -> int | None:
    status, body = request(
        "POST",
        f"/repos/{OWNER}/{REPO}/milestones",
        {
            "title": "MVP follow-up",
            "description": "Post-MVP improvements for MyClock.",
            "state": "open",
        },
    )
    if status == 201 and isinstance(body, dict):
        print("Created milestone: MVP follow-up")
        return int(body["number"])
    if status == 422:
        print("Milestone may already exist: MVP follow-up")
        return None
    print(f"Milestone skipped: HTTP {status}")
    return None


def create_issue(issue: dict, milestone: int | None) -> None:
    payload = dict(issue)
    if milestone is not None:
        payload["milestone"] = milestone
    status, _ = request("POST", f"/repos/{OWNER}/{REPO}/issues", payload)
    if status == 201:
        print(f"Created issue: {issue['title']}")
    elif status == 422:
        print(f"Issue skipped: {issue['title']}")
    else:
        print(f"Issue skipped: {issue['title']} HTTP {status}")


def run(command: list[str]) -> None:
    print("+", " ".join(command))
    subprocess.run(command, check=True)


def configure_remote() -> None:
    remote_url = f"https://github.com/{OWNER}/{REPO}.git"
    result = subprocess.run(["git", "remote"], text=True, capture_output=True, check=True)
    if "origin" in result.stdout.splitlines():
        run(["git", "remote", "set-url", "origin", remote_url])
    else:
        run(["git", "remote", "add", "origin", remote_url])


def main() -> int:
    create_repo()
    configure_remote()
    run(["git", "push", "-u", "origin", "main"])

    for label in LABELS:
        create_label(label)
    milestone = create_milestone()
    for issue in ISSUES:
        create_issue(issue, milestone)

    print(f"Bootstrap complete: https://github.com/{OWNER}/{REPO}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
