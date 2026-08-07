#!/usr/bin/env python3
"""Verify that the github-release environment actually enforces something.

check_project_metadata.py reads the workflow and confirms the publish job
names this environment. That is a string in a YAML file. It says nothing about
whether the environment has reviewers, a branch restriction, or any effect at
all -- and for months it printed a reassuring line while the environment's
protection_rules list was empty and every release published unattended.

This script asks GitHub. It needs network and an authenticated `gh`, so it
cannot live inside the offline metadata check; it is the measured half of a
control whose requested half is checked there.

    python tools/check_release_protection.py [owner/repo]

Exit codes: 0 the environment enforces review and restricts deployment;
1 it does not; 2 the question could not be asked. Two is not a pass -- an
unanswerable question about a safety control is reported as unanswerable,
never as an answer.
"""

from __future__ import annotations

import json
import shutil
import subprocess
import sys

DEFAULT_REPO = "patnawa/Chipwright"
ENVIRONMENT = "github-release"
REQUIRED_TAG_PATTERN = "v*"


def gh_json(*args: str):
    """Run gh and parse its JSON, or raise RuntimeError with the reason."""
    if shutil.which("gh") is None:
        raise RuntimeError("the GitHub CLI (gh) is not on PATH")
    try:
        out = subprocess.run(
            ("gh",) + args,
            capture_output=True,
            text=True,
            check=False,
            timeout=60,
        )
    except (OSError, subprocess.SubprocessError) as exc:
        raise RuntimeError(f"could not run gh: {exc}") from exc
    if out.returncode != 0:
        raise RuntimeError((out.stderr or out.stdout).strip() or "gh failed")
    try:
        return json.loads(out.stdout)
    except json.JSONDecodeError as exc:
        raise RuntimeError(f"gh returned output that is not JSON: {exc}") from exc


def main() -> int:
    repo = sys.argv[1] if len(sys.argv) > 1 else DEFAULT_REPO

    try:
        env = gh_json("api", f"repos/{repo}/environments/{ENVIRONMENT}")
        policies = gh_json(
            "api",
            f"repos/{repo}/environments/{ENVIRONMENT}/deployment-branch-policies",
        )
    except RuntimeError as exc:
        # Deliberately its own exit code. "I could not check" must never be
        # reported in the same breath as "I checked and it is fine".
        print(f"UNVERIFIED: {exc}", file=sys.stderr)
        print(
            "UNVERIFIED: the release gate was not confirmed. This is not a pass.",
            file=sys.stderr,
        )
        return 2

    failures: list[str] = []

    rules = {rule.get("type"): rule for rule in env.get("protection_rules", [])}

    reviewers_rule = rules.get("required_reviewers")
    if not reviewers_rule:
        failures.append(
            f"{ENVIRONMENT} has no required reviewers, so the publish job "
            "runs unattended and any pushed tag publishes a release"
        )
    else:
        names = [
            r.get("reviewer", {}).get("login") or r.get("reviewer", {}).get("slug")
            for r in reviewers_rule.get("reviewers", [])
        ]
        if not names:
            failures.append(f"{ENVIRONMENT} requires review but names no reviewer")
        else:
            print(f"reviewers: {', '.join(n for n in names if n)}")
            # Reported rather than failed. docs/releasing.md asks for
            # prevent-self-review, but a project with one maintainer cannot
            # have it: the only person who could approve would be forbidden
            # from approving, and no release could ever be published. Saying
            # so is more useful than a rule nobody can satisfy.
            if not reviewers_rule.get("prevent_self_review"):
                print(
                    "note: self-review is permitted. With a single maintainer "
                    "that is the only workable setting; with two or more, turn "
                    "it on."
                )

    if env.get("can_admins_bypass"):
        failures.append(
            f"{ENVIRONMENT} lets administrators bypass review, which makes the "
            "reviewer requirement advisory rather than enforced"
        )

    branch_policy = env.get("deployment_branch_policy") or {}
    if not branch_policy.get("custom_branch_policies"):
        failures.append(
            f"{ENVIRONMENT} does not restrict which refs may deploy, so a "
            "branch push could reach the publish job"
        )
    else:
        patterns = [
            (p.get("type"), p.get("name"))
            for p in policies.get("branch_policies", [])
        ]
        if ("tag", REQUIRED_TAG_PATTERN) not in patterns:
            failures.append(
                f"{ENVIRONMENT} does not restrict deployment to "
                f"{REQUIRED_TAG_PATTERN} tags; it allows {patterns or 'nothing'}"
            )
        else:
            print(f"deployment restricted to: tag {REQUIRED_TAG_PATTERN}")

    if failures:
        for failure in failures:
            print(f"FAILED: {failure}", file=sys.stderr)
        return 1

    print(f"{ENVIRONMENT} enforces review and restricts deployment to tags")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
