# Nix templates

`flake-modules` is the default Bun/TypeScript template with flake-parts and
treefmt. `flake-basic` provides a smaller Bun development shell. Both target
x86_64 Linux.

```sh
# In an empty project directory:
nix flake init --template github:meatcar/nix-templates#flake-modules
# Or: nix flake init --template github:meatcar/nix-templates#flake-basic
nix develop
```

For disposable environments, add the optional [sandbox overlay](templates/sandbox/.agents/sandbox/AGENTS.md):

```sh
nix flake init --template github:meatcar/nix-templates#sandbox
chmod +x .agents/setup .agents/resume
```

Customize `.agents/Taskfile.yml` before running setup. The overlay replaces the
older embedded Amp scripts; existing projects must remove their old
`.agents/setup` and `.agents/resume` before applying it.

Commit generated lockfiles and lifecycle scripts. Run `nix flake check -L` to
validate this repository; see [tests/README.md](tests/README.md) for targeted and
cold-bootstrap checks.

## Project-owned CI and auto-merge

Templates copy their CI into each repository; the project owns it from then on.
The `flake-modules` workflow runs `nix flake check -L`, covering formatting,
linting, typechecking, unit tests, and Playwright browser tests in Nix sandboxes.
Bun dependencies use bun2nix and integrity hashes from the committed `bun.lock`,
so Renovate does not need to maintain a separate dependency-cache hash.

Consumers must require **`check`** from GitHub Actions. A repository admin can run
the template's `scripts/bootstrap-automerge.sh` to install that ruleset before
enabling auto-merge. See the [consumer setup guide](templates/flake-modules/README.md#ci-and-safe-auto-merge)
for permissions, migration, dependency updates, and the opt-in Renovate preset.
