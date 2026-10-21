import json
import os
import subprocess
import sys
from pathlib import Path

import pytest


def test_bun_runs_the_project():
    result = subprocess.run(
        ["bun", "run", "src/index.ts"],
        check=True,
        capture_output=True,
        text=True,
    )
    assert result.stdout == "Hello, Bun!\n"


def test_bun_test_suite_passes():
    subprocess.run(["bun", "test"], check=True)


def test_treefmt_formats_nix(tmp_path):
    source = tmp_path / "flake.nix"
    source.write_text("{answer=42;}")
    subprocess.run(["treefmt"], cwd=tmp_path, check=True)
    assert source.read_text() == "{ answer = 42; }\n"
    subprocess.run(["treefmt", "--ci"], cwd=tmp_path, check=True)


@pytest.fixture
def github_api(tmp_path, monkeypatch):
    state = tmp_path / "state.json"
    state.write_text(json.dumps({"rulesets": [], "calls": [], "fail": None}))
    gh = tmp_path / "gh"
    gh.write_text(
        f"#!{sys.executable}\n"
        '''import json, os, sys
from pathlib import Path
state = Path(os.environ["GH_TEST_STATE"])
data = json.loads(state.read_text())
args = sys.argv[1:]
if args[0] == "repo":
    print("owner/project")
    sys.exit(0)
method = args[args.index("--method") + 1] if "--method" in args else "GET"
endpoint = args[1]
body = json.load(sys.stdin) if "--input" in args else None
data["calls"].append({"method": method, "endpoint": endpoint, "body": body})
if data["fail"] == method:
    state.write_text(json.dumps(data))
    sys.exit(1)
if method == "GET":
    for ruleset in data["rulesets"]:
        if ruleset["name"] == "Default branch: CI must pass":
            print(ruleset["id"])
elif method in ("POST", "PUT"):
    if method == "POST":
        data["rulesets"].append({"id": 42, "name": body["name"]})
    print("{}")
state.write_text(json.dumps(data))
'''
    )
    gh.chmod(0o755)
    monkeypatch.setenv("PATH", f"{tmp_path}:{os.environ['PATH']}")
    monkeypatch.setenv("GH_TEST_STATE", str(state))
    return state


def test_automerge_bootstrap_is_idempotent(github_api):
    script = Path("scripts/bootstrap-automerge.sh").resolve()
    subprocess.run(["bash", str(script)], check=True)
    subprocess.run(["bash", str(script), "owner/project"], check=True)
    state = json.loads(github_api.read_text())
    assert len(state["rulesets"]) == 1
    assert [call["method"] for call in state["calls"]] == [
        "GET", "POST", "PATCH", "GET", "PUT", "PATCH"
    ]
    create, enable = state["calls"][1:3]
    assert create["body"] == {
        "name": "Default branch: CI must pass",
        "target": "branch",
        "enforcement": "active",
        "conditions": {"ref_name": {"include": ["~DEFAULT_BRANCH"], "exclude": []}},
        "bypass_actors": [
            {"actor_id": 5, "actor_type": "RepositoryRole", "bypass_mode": "always"}
        ],
        "rules": [{"type": "required_status_checks", "parameters": {
            "strict_required_status_checks_policy": True,
            "required_status_checks": [{"context": "check / check", "integration_id": 15368}],
        }}],
    }
    assert state["calls"][4]["body"] == create["body"]
    assert state["calls"][4]["endpoint"] == "repos/owner/project/rulesets/42"
    assert enable["endpoint"] == "repos/owner/project"
    assert enable["body"] == {"allow_auto_merge": True}


@pytest.mark.parametrize("method", ["GET", "POST", "PUT"])
def test_automerge_bootstrap_does_not_enable_after_ruleset_failure(github_api, method):
    state = json.loads(github_api.read_text())
    state["fail"] = method
    if method == "PUT":
        state["rulesets"] = [{"id": 42, "name": "Default branch: CI must pass"}]
    github_api.write_text(json.dumps(state))
    result = subprocess.run(["bash", "scripts/bootstrap-automerge.sh", "owner/project"])
    assert result.returncode != 0
    calls = json.loads(github_api.read_text())["calls"]
    assert calls
    assert all(call["method"] != "PATCH" for call in calls)


def test_automerge_bootstrap_refuses_duplicate_rulesets(github_api):
    state = json.loads(github_api.read_text())
    state["rulesets"] = [
        {"id": i, "name": "Default branch: CI must pass"} for i in [42, 43]
    ]
    github_api.write_text(json.dumps(state))
    result = subprocess.run(["bash", "scripts/bootstrap-automerge.sh", "owner/project"])
    assert result.returncode != 0
    assert [c["method"] for c in json.loads(github_api.read_text())["calls"]] == ["GET"]
