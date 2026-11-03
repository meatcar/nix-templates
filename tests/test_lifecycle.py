import json
import posixpath

import pytest
import yaml


def test_setup_is_repeatable_and_shell_hooks_work(sandbox_project):
    sandbox = sandbox_project
    (sandbox.project / ".env").write_text("SANDBOX_TEST_DOTENV=initial\n")
    (sandbox.home / ".bash_profile").write_text("export BEFORE=1\n")
    for phase in ("setup", "setup", "resume"):
        sandbox.run(f".agents/{phase}")
    settings = (sandbox.home / ".config/nix/nix.conf").read_text().splitlines()
    assert settings.count("sandbox = false") == 1
    assert settings.count("experimental-features = nix-command flakes") == 1
    profile = (sandbox.home / ".bash_profile").read_text().splitlines()
    assert profile[0] == "export BEFORE=1"
    assert profile[-1] == "fi"
    assert profile.count(f"# sandbox environment: {sandbox.guest_project}") == 1
    assert (sandbox.home / ".bashrc").read_text().count(".sandbox-env.sh") == 2
    command = (
        "bun --eval 'console.log(JSON.stringify(process.env.SANDBOX_TEST_DOTENV))'"
    )
    for args in (
        ("bash", "--login", "-c", command),
        (
            "bash",
            "--noprofile",
            "--norc",
            "-c",
            f'source "$HOME/.bashrc"; _direnv_hook; {command}',
        ),
    ):
        assert json.loads(sandbox.run(*args).stdout) == "initial"
    result = sandbox.run("bash", "--login", "-c", "command -v task")
    assert result.stdout.strip().startswith(
        f"{sandbox.guest_home}/.local/share/sandbox/task-v"
    )


@pytest.mark.parametrize(
    ("directory", "working_directory", "active"),
    [
        (".", None, True),
        ("nested", None, True),
        ("../project with spaces-other", None, False),
        # Amp's headless service logs in from / before entering AMP_WORKING_DIRECTORY.
        ("/", ".", True),
        ("/", "../project with spaces-other", False),
    ],
)
def test_login_environment_is_scoped_and_activates_once_after_env_loader(
    sandbox_project, directory, working_directory, active
):
    sandbox = sandbox_project
    with (sandbox.project / ".envrc").open("a") as envrc:
        envrc.write(
            "\nexport SANDBOX_TEST_ACTIVATIONS=$((${SANDBOX_TEST_ACTIVATIONS:-0} + 1))\n"
            'export NODE_PATH="$PWD/node_modules"\n'
        )
    sandbox.run(".agents/setup")
    with (sandbox.home / ".bash_profile").open("a") as profile:
        profile.write("export PATH=/bin\n")
    sandbox.run(".agents/resume")
    if active:
        probe = r"""
            test "$IN_NIX_SHELL" = impure
            test "$NODE_PATH" = "$2/node_modules"
            test "$SANDBOX_TEST_ACTIVATIONS" = 1
            test "$(bun --eval 'console.log(6 * 7)')" = 42
            bash --login -ec 'test "$SANDBOX_TEST_ACTIVATIONS" = 1; command -v bun'
        """
    else:
        probe = r"""
            test -z "${SANDBOX_TEST_ACTIVATIONS:-}"
            test -z "${IN_NIX_SHELL:-}"
            test -z "${NODE_PATH:-}"
            ! command -v bun
        """
    sandbox.run(
        "bash",
        "-ec",
        r"""
            mkdir -p -- "$1"
            cd -- "$1"
            exec env -i HOME="$HOME" PATH=/bin NIX_REMOTE=local NIX_CONFIG="$NIX_CONFIG" \
                ${4:+AMP_WORKING_DIRECTORY="$4"} bash --login -ec "$2" bash "$1" "$3"
        """,
        "bash",
        directory,
        probe,
        sandbox.guest_project,
        posixpath.normpath(posixpath.join(sandbox.guest_project, working_directory))
        if working_directory
        else "",
    )


@pytest.mark.parametrize("phase", ["setup", "resume"])
def test_hooks_order_refresh_credentials_and_isolate_commands(
    configured_project, phase
):
    sandbox = configured_project
    sandbox.run("direnv", "exec", ".", f".agents/{phase}")
    expected = [
        "before_nix",
        "auth",
        f"{phase}_auth",
        "pre_deps",
        "deps",
        "post_deps",
        "prep",
        "check",
        "ready",
    ]
    if phase == "setup":
        expected.append("cleanup")
    assert (sandbox.project / "phases").read_text().splitlines() == expected
    assert (sandbox.project / "runtime-ready").exists()
    assert not (sandbox.project / "setup-credential").exists()


@pytest.mark.parametrize("phase", ["setup", "resume"])
@pytest.mark.parametrize(
    ("failure", "completed"),
    [
        ("before_nix", []),
        ("auth", ["before_nix", "auth"]),
        ("deps", ["before_nix", "auth", "{phase}_auth", "pre_deps"]),
        (
            "check",
            [
                "before_nix",
                "auth",
                "{phase}_auth",
                "pre_deps",
                "deps",
                "post_deps",
                "prep",
            ],
        ),
    ],
)
def test_failure_stops_work_and_setup_still_cleans(
    configured_project, phase, failure, completed
):
    sandbox = configured_project
    (sandbox.project / f"{failure}-fails").touch()
    result = sandbox.run("direnv", "exec", ".", f".agents/{phase}", check=False)
    assert result.returncode != 0
    expected = [name.format(phase=phase) for name in completed]
    if phase == "setup":
        expected.append("cleanup")
    phases = sandbox.project / "phases"
    assert (phases.read_text().splitlines() if phases.exists() else []) == expected
    assert not (sandbox.project / "runtime-ready").exists()
    assert not (sandbox.project / "setup-credential").exists()


def test_cleanup_failure_fails_setup(configured_project):
    sandbox = configured_project
    (sandbox.project / "cleanup-fails").touch()
    result = sandbox.run("direnv", "exec", ".", ".agents/setup", check=False)
    assert result.returncode != 0
    assert (sandbox.project / "phases").read_text().splitlines()[-2:] == [
        "ready",
        "cleanup",
    ]
    assert (sandbox.project / "setup-credential").exists()


@pytest.mark.parametrize("phase", ["setup", "resume"])
def test_broken_devshell_prevents_work_but_not_setup_cleanup(sandbox_project, phase):
    sandbox = sandbox_project
    taskfile_path = sandbox.project / ".agents/Taskfile.yml"
    taskfile = yaml.safe_load(taskfile_path.read_text())
    taskfile["tasks"]["before_nix"]["cmds"] = ["touch started"]
    taskfile["tasks"]["ready"]["cmds"] = ["touch accepted"]
    taskfile["tasks"]["setup_cleanup"]["cmds"] = ["touch cleaned"]
    taskfile_path.write_text(yaml.safe_dump(taskfile))
    with (sandbox.project / ".envrc").open("a") as envrc:
        envrc.write("\nexit 19\n")
    sandbox.run("direnv", "allow", ".")
    result = sandbox.run(f".agents/{phase}", check=False)
    assert result.returncode != 0
    assert (sandbox.project / "started").exists()
    assert not (sandbox.project / "accepted").exists()
    assert (sandbox.project / "cleaned").exists() == (phase == "setup")
