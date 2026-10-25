import json

import pytest


def test_generated_devshell(sandbox):
    result = sandbox.run(
        "nix",
        "develop",
        "--offline",
        "--command",
        "bun",
        "--eval",
        "console.log(JSON.stringify([7, 2, 5].toSorted()))",
    )
    assert json.loads(result.stdout) == [2, 5, 7]


def test_generated_devshell_bun_rejects_brotli_block_switch_fixture(sandbox):
    sandbox.run(
        "nix",
        "develop",
        "--offline",
        "--command",
        "bun",
        f"{sandbox.config['source']}/tests/fixtures/brotli-cve-2026-111497.js",
    )


def test_sandbox_layers_without_replacing_project_files(sandbox):
    originals = {
        path: (sandbox.project / path).read_bytes()
        for path in ("flake.nix", "flake.lock", ".envrc", ".gitignore")
    }
    (sandbox.project / "Taskfile.yml").write_text("project taskfile\n")
    sandbox.run(
        "nix", "flake", "init", "-t", f"path:{sandbox.config['source']}#sandbox"
    )
    for path, content in originals.items():
        assert (sandbox.project / path).read_bytes() == content
    assert (sandbox.project / "Taskfile.yml").read_text() == "project taskfile\n"
    assert not (sandbox.project / ".amp").exists()
    for path in (
        "setup",
        "resume",
        "Taskfile.yml",
        "sandbox/run.sh",
        "sandbox/provision-nix.sh",
        "sandbox/provision-shell.sh",
        "sandbox/task.sha256",
    ):
        assert (sandbox.project / ".agents" / path).is_file()
    tracked = sandbox.run(
        "git", "ls-files", "--cached", "--others", "--exclude-standard"
    ).stdout
    assert ".agents/setup" in tracked.splitlines()


def test_direnv_loads_dotenv_and_devshell(sandbox):
    (sandbox.project / ".env").write_text("TEMPLATE_TEST_VALUE=from-dotenv\n")
    sandbox.run("direnv", "allow", ".")
    result = sandbox.run(
        "direnv",
        "exec",
        ".",
        "bun",
        "--eval",
        "console.log(JSON.stringify({value: process.env.TEMPLATE_TEST_VALUE, path: process.env.PATH}))",
    )
    environment = json.loads(result.stdout)
    assert environment["value"] == "from-dotenv"
    if sandbox.template == "flake-modules":
        assert f"{sandbox.guest_project}/node_modules/.bin" in environment[
            "path"
        ].split(":")


def test_direnv_rejects_broken_envrc(sandbox):
    with (sandbox.project / ".envrc").open("a") as envrc:
        envrc.write("\nexit 19\n")
    sandbox.run("direnv", "allow", ".")
    result = sandbox.run("direnv", "exec", ".", "touch", "accepted", check=False)
    assert result.returncode != 0
    assert not (sandbox.project / "accepted").exists()


@pytest.mark.xfail(
    strict=True,
    raises=SyntaxError,
    reason="Nix 2.34 develop.cc makeRcScript inserts the project path without shell escaping",
)
def test_devshell_in_quoted_project_path(sandbox):
    sandbox.guest_project = "/work/project ' $HOME"
    result = sandbox.run(
        "nix",
        "develop",
        "--offline",
        "--command",
        "bun",
        "--eval",
        "console.log(42)",
        check=False,
    )
    if (
        result.returncode == 2
        and "syntax error near unexpected token `}'" in result.stderr
    ):
        raise SyntaxError(result.stderr)
    assert result.returncode == 0, result.stdout + result.stderr
    assert result.stdout.strip() == "42"
