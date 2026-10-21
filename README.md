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

## Shared CI and auto-merge

The reusable [Bun + Nix workflow](.github/workflows/bun-nix-check.yml) runs frozen
dependency installation, checks, unit tests, flake checks, and optional `build`
and `test:e2e` scripts. The `flake-modules` template calls it with a SHA pin that
Renovate can update, and includes Nix-managed Playwright browsers.

Consumers must require **`check / check`** from GitHub Actions. A repository admin
can run the template's `scripts/bootstrap-automerge.sh` to install that ruleset
before enabling auto-merge. See the [consumer setup guide](templates/flake-modules/README.md#ci-and-safe-auto-merge)
for the pinned caller, permissions, migration, and opt-in Renovate preset.
