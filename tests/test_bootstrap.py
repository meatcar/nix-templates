import pytest


@pytest.mark.parametrize("missing", ["nix", "direnv", "task"])
def test_resume_never_installs_missing_tools(sandbox_project, download_probe, missing):
    sandbox = sandbox_project
    if missing == "nix":
        (sandbox.home / ".nix-profile").unlink()
    elif missing == "direnv":
        (sandbox.project / "host-bin/direnv").unlink()
    else:
        sandbox.task.unlink()
    result = sandbox.run(".agents/resume", env=download_probe, check=False)
    assert result.returncode != 0
    expected = "Task unavailable" if missing == "task" else "Devshell unavailable"
    assert f"{expected}; run .agents/setup" in result.stderr
    assert not (sandbox.home / "download-attempted").exists()


def test_task_download_requires_valid_checksum(sandbox_project, download_probe):
    sandbox = sandbox_project
    sandbox.task.unlink()
    result = sandbox.run(".agents/setup", env=download_probe, check=False)
    assert result.returncode != 0
    assert "FAILED" in result.stdout
    assert (sandbox.home / "download-attempted").exists()
    assert not sandbox.task.exists()
    assert not sandbox.task.with_suffix(".tmp").exists()


def test_setup_installs_missing_direnv_from_pinned_inputs(
    sandbox_project, download_probe
):
    sandbox = sandbox_project
    (sandbox.project / "host-bin/direnv").unlink()
    sandbox.run(".agents/setup", env=download_probe)
    result = sandbox.run(
        "bash", "--login", "-c", "command -v direnv", env=download_probe
    )
    assert result.stdout.strip() == f"{sandbox.guest_home}/.nix-profile/bin/direnv"
    assert not (sandbox.home / "download-attempted").exists()
