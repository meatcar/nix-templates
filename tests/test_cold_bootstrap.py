import json
import shutil
import subprocess
from pathlib import Path

import pytest
import yaml
from conftest import Sandbox, template_lock


@pytest.mark.cold
@pytest.mark.parametrize("template", ["flake-basic", "flake-modules"])
def test_bootstrap_from_empty_nix_then_resume_offline(
    tmp_path, config, request, template
):
    cold_root = request.config.getoption("--cold-root")
    assert cold_root, "Use nix run .#test-sandbox-cold"
    sandbox = Sandbox(tmp_path, config, template, cold_root=cold_root)
    request.addfinalizer(sandbox.make_writable)
    source = Path(config["source"]) / "templates"
    for name in (template, "sandbox"):
        shutil.copytree(source / name, sandbox.project, dirs_exist_ok=True)
        sandbox.project.chmod(0o755)
    for path in sandbox.project.rglob("*"):
        if not path.is_symlink():
            path.chmod(path.stat().st_mode | 0o200)
    (sandbox.project / "flake.lock").write_text(
        json.dumps(template_lock(config, template))
    )
    for args in (("init", "--template="), ("add", ".")):
        subprocess.run(
            [config["tools"] + "/bin/git", "-C", str(sandbox.project), *args],
            env={"HOME": str(sandbox.home), "GIT_CONFIG_NOSYSTEM": "1"},
            capture_output=True,
            check=True,
        )
    taskfile_path = sandbox.project / ".agents/Taskfile.yml"
    taskfile = yaml.safe_load(taskfile_path.read_text())
    taskfile["tasks"]["ready"]["cmds"] = [
        "bun --eval 'console.log(JSON.stringify({phase: process.env.SANDBOX_LIFECYCLE, answer: 6 * 7}))' >> ready.jsonl"
    ]
    taskfile_path.write_text(yaml.safe_dump(taskfile))
    sandbox.run(
        "bash",
        "-ec",
        'test -z "$(ls -A /nix)"; ! command -v nix; ! command -v task; ! command -v direnv',
    )
    sandbox.run("bash", ".agents/setup", network=True, timeout=600)
    sandbox.run("bash", ".agents/resume")
    records = [
        json.loads(line)
        for line in (sandbox.project / "ready.jsonl").read_text().splitlines()
    ]
    assert records == [
        {"phase": "setup", "answer": 42},
        {"phase": "resume", "answer": 42},
    ]
