"""Keep the game build for every change except verified Meridian documentation."""
import json
import os
import re
import subprocess
from pathlib import Path

STORY_LINK = (b"Read [the commander's story](docs/meridian/INTENDED-GAME-STORY-WALKTHROUGH.md) "
              b"for Rowan Calder's intended complete journey, with compact status badges and a full mission map.\n\n")
SHA = re.compile(r"[0-9a-f]{40}")


def git(repo, *args):
    return subprocess.check_output(
        ["git", "--no-optional-locks", *args], cwd=repo,
        stderr=subprocess.DEVNULL)


def requires_build(repo, event_name, event):
    """Unknown events, unavailable history and malformed inputs always require the build."""
    try:
        if event_name == "pull_request":
            base = event["pull_request"]["base"]["sha"]
            head = event["pull_request"]["head"]["sha"]
        elif event_name == "push":
            base, head = event["before"], event["after"]
        else:
            return True
        if not all(isinstance(s, str) and SHA.fullmatch(s) and s != "0" * 40
                   for s in (base, head)):
            return True
        if event_name == "pull_request":
            base = git(repo, "merge-base", base, head).decode("ascii").strip()
        raw = git(repo, "diff", "--no-ext-diff", "--no-textconv", "--no-renames",
                  "--name-only", "-z", base, head, "--")
        if not raw or not raw.endswith(b"\0"):
            return True
        paths = raw[:-1].split(b"\0")
        for path in paths:
            if path.startswith(b"docs/meridian/"):
                continue
            if path == b"README.md":
                before = git(repo, "show", base + ":README.md")
                after = git(repo, "show", head + ":README.md")
                if (STORY_LINK not in before and after.count(STORY_LINK) == 1
                        and after.replace(STORY_LINK, b"", 1) == before):
                    continue
            return True
        return False
    except (KeyError, TypeError, ValueError, UnicodeError, OSError, subprocess.SubprocessError):
        return True


if __name__ == "__main__":
    try:
        event = json.loads(Path(os.environ["GITHUB_EVENT_PATH"]).read_text())
        needed = requires_build(Path.cwd(), os.environ["GITHUB_EVENT_NAME"], event)
    except (KeyError, OSError, ValueError):
        needed = True
    print("true" if needed else "false")
