# Template tests

Run from the repository root on x86_64 Linux with unprivileged user namespaces:

```sh
nix flake check -L
nix run .#test-sandbox -- -k cleanup
nix run .#test-sandbox -- -n 0 --durations=10
```

Each base template owns `checks.devshell` and `tests/test_devshell.py`. These check
the actual shell's packages and hook. The root flake aggregates them. Repository
pytest tests additionally initialize templates and run real `nix develop`, direnv,
Task, setup, and resume inside Bubblewrap. Two workers run the base templates
independently; `-n 0` runs serially.

Normal tests have no network, host home, daemon socket, or host Nix configuration.
Only declared store paths are mounted read-only. Each test gets its own writable
home, project, and Nix database. Inputs come from the root `flake.lock`; update it
to advance the test toolchains.

The quoted-project-path cases are strict expected failures for Nix 2.34's
[unescaped output-path replacement](https://github.com/NixOS/nix/blob/2.34.8/src/nix/develop.cc#L330-L417).
Unexpected errors still fail. Remove the marker when an updated Nix passes them.

## Live cold bootstrap

```sh
nix run .#test-sandbox-cold
```

Starts with an empty `/nix` and static host tools, without mounting any host store
paths. Setup downloads Task and Nix and realizes the pinned project shell. Resume
then runs with networking disabled. This uses the template's live installer URL,
so it is excluded from `flake check`. CI exposes it as a manual workflow option.
Nix's nested sandbox and supplementary-group dropping are disabled because the
outer unprivileged namespace cannot support them.

CI uses Ubuntu 22.04 to avoid Ubuntu 24.04's default AppArmor restriction on
unprivileged user namespaces. Unsupported hosts fail rather than skip isolation.
