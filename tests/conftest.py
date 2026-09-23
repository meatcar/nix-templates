import json
import os
import subprocess
from pathlib import Path

import pytest


class Sandbox:
    def __init__(self, path, config, template):
        self.path = path
        self.config = config
        self.template = template
        self.home = path / "home"
        self.project = path / "project"
        for directory in (self.home, self.project, path / "nix"):
            directory.mkdir()
        self.guest_project = "/work/project with spaces"

    def run(self, *args, env=None, check=True, stdin=None):
        config = self.config
        command = [
            "bwrap",
            "--unshare-all",
            "--uid",
            "0",
            "--gid",
            "0",
            "--die-with-parent",
            "--new-session",
            "--clearenv",
            "--bind",
            str(self.path / "nix"),
            "/nix",
        ]
        for store_path in (
            (Path(config["closure"]) / "store-paths").read_text().splitlines()
        ):
            command.extend(["--ro-bind", store_path, store_path])
        command.extend(
            [
                "--proc",
                "/proc",
                "--dev",
                "/dev",
                "--tmpfs",
                "/tmp",
                "--bind",
                str(self.home),
                "/root",
                "--bind",
                str(self.project),
                self.guest_project,
                "--symlink",
                config["tools"] + "/bin",
                "/bin",
                "--dir",
                "/usr",
                "--symlink",
                config["tools"] + "/bin",
                "/usr/bin",
                "--ro-bind",
                config["certificates"],
                "/etc/ssl/certs/ca-certificates.crt",
                "--chdir",
                self.guest_project,
            ]
        )
        environment = {
            "HOME": "/root",
            "USER": "root",
            "PATH": config["tools"] + "/bin",
            "NIX_REMOTE": "local",
            "NIX_CONFIG": "experimental-features = nix-command flakes\nbuild-users-group =\nsandbox = false\nsubstituters =\nflake-registry =",
            "NIX_SSL_CERT_FILE": "/etc/ssl/certs/ca-certificates.crt",
        }
        for name, value in (environment | (env or {})).items():
            command.extend(["--setenv", name, value])
        result = subprocess.run(
            [*command, "--", *args],
            input=stdin,
            capture_output=True,
            text=True,
            timeout=120,
        )
        if check:
            assert result.returncode == 0, result.stdout + result.stderr
        return result


@pytest.fixture(scope="session")
def config():
    return json.loads(Path(os.environ["SANDBOX_TEST_CONFIG"]).read_text())


def template_lock(config, template):
    """Reuse the repository's locked graph with the template as its root."""
    lock = json.loads((Path(config["source"]) / "flake.lock").read_text())
    nodes = lock["nodes"]
    selected = {}

    def resolve(edge):
        if isinstance(edge, str):
            return edge
        node = lock["root"]
        for name in edge:
            node = resolve(nodes[node]["inputs"][name])
        return node

    def collect(edge):
        name = resolve(edge)
        if name not in selected:
            selected[name] = dict(nodes[name])
            if "inputs" in nodes[name]:
                selected[name]["inputs"] = {
                    key: collect(value) for key, value in nodes[name]["inputs"].items()
                }
        return name

    root = collect(config["templates"][template])
    selected[root] = {"inputs": selected[root]["inputs"]}
    return {"version": lock["version"], "root": root, "nodes": selected}


@pytest.fixture(scope="session", params=["flake-basic", "flake-modules"])
def prepared_sandbox(tmp_path_factory, config, request):
    sandbox = Sandbox(tmp_path_factory.mktemp(request.param), config, request.param)
    registration = (Path(config["closure"]) / "registration").read_text()
    sandbox.run("nix-store", "--load-db", stdin=registration)
    sandbox.run(
        "nix", "flake", "init", "-t", f"path:{config['source']}#{request.param}"
    )
    (sandbox.project / "flake.lock").write_text(
        json.dumps(template_lock(config, request.param))
    )
    sandbox.run("nix", "flake", "lock", "--offline")
    sandbox.run("git", "init", "--quiet")
    sandbox.run("git", "add", ".")
    sandbox.run("nix", "develop", "--offline", "--command", "true")
    return sandbox


@pytest.fixture
def sandbox(tmp_path, config, prepared_sandbox):
    sandbox = Sandbox(tmp_path, config, prepared_sandbox.template)
    subprocess.run(
        [
            "cp",
            "-a",
            "--reflink=auto",
            str(prepared_sandbox.path) + "/.",
            str(tmp_path),
        ],
        check=True,
    )
    return sandbox
