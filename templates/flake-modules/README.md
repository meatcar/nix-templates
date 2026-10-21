# Bun + Nix modules

Run `nix develop` or approve `.envrc` with `direnv allow`, then `bun install`.
Run `nix flake check -L` for the same checks locally and in CI. Commit `flake.lock`
and `bun.lock`. This template targets x86_64 Linux.

For disposable environments, add `github:meatcar/nix-templates#sandbox` with
`nix flake init -t`, then follow `.agents/sandbox/AGENTS.md`.

## CI and safe auto-merge

The copied `.github/workflows/ci.yml` belongs to this project. It checks out the
repository, installs Nix and its cache, then runs `nix flake check -L`. There is
no shared workflow or central CI version to update. Edit the workflow and flake
checks as the project grows; builds and deployment policy belong here too.

Keep the job named `check`. The exact required status-check context is **`check`**,
not `CI` or `check / check`.

`nix/flake-modules/checks.nix` defines sandboxed `typecheck`, `lint`, `unit`, and
`e2e` checks. `treefmt.nix` supplies the formatting check, and `devshell.nix`
checks the development environment. Use `bun test`, `bun run typecheck`,
`bun run lint`, or `bun run test:e2e` in the devshell for quick iterations.

Sandboxed failures do not put `test-results/` in the checkout, so CI does not
upload that workspace directory. To retain a failed browser build and its traces,
run `nix build -L --keep-failed .#checks.x86_64-linux.e2e` and inspect the build
directory reported by Nix.

After the workflow is on the default branch, a repository admin runs this once
from a trusted checkout with Bash and an authenticated GitHub CLI:

```sh
bash scripts/bootstrap-automerge.sh             # current GitHub repository
bash scripts/bootstrap-automerge.sh OWNER/REPO  # explicit target
```

The account/token needs repository administration write access (classic tokens
need `repo`; fine-grained tokens need Administration: read and write). The repo's
GitHub plan must support rulesets. Orb tokens may return 403; use your admin
session, not CI. The script creates or updates the repository ruleset named
`Default branch: CI must pass`, requiring `check` from GitHub Actions
(integration 15368), strict up-to-date checks, and an always-on repository-admin
bypass (RepositoryRole 5). Only a successful ruleset write enables **Allow
auto-merge**. Rerunning updates the same ruleset; it does not alter other rulesets
or request auto-merge on individual PRs. Rerun it to migrate its ruleset from the
former `check / check` context; review any other branch protections separately.

Once published, add `github>meatcar/renovate-config:automerge` to `extends` in
`.renovaterc.jsonc` to opt into the shared auto-merge policy. It is not enabled
here because the preset is being added separately. The existing local
minor/patch auto-merge rule remains; the ruleset is the merge gate.

## Sandboxed dependencies

The committed `bun.lock` is the dependency source of truth. During Nix evaluation,
bun2nix converts it to Nix fetchers in an import-from-derivation (IFD) build. Each
registry tarball is a fixed-output fetch using the integrity hash already in the
lockfile. The bun2nix hook installs from that cache without network access, then
each check runs in the Nix sandbox with a frozen lockfile and lifecycle scripts
disabled. Native npm binaries are patched for Nix's loader, and Playwright gets
a Nix font configuration. Fallow's npm signature check is disabled only in these
derivations because ELF patching changes its signed bytes; Nix still verifies
the original tarball integrity before patching.

There is no aggregate `node_modules` hash or generated `bun.nix` to maintain.
Renovate's Bun manager updates `package.json` and `bun.lock`, including package
integrities; the next Nix evaluation regenerates the fetchers automatically. Its
Nix manager updates the bun2nix input in `flake.lock`. Manual dependency changes
use `bun install` and commit the updated lockfile. Keep IFD enabled; non-registry
dependencies or packages requiring install scripts may need project-specific
changes to `checks.nix`.

## Playwright

Run `bun run test:e2e` inside `nix develop`. Nix supplies the browsers; do not run
`playwright install`. `@playwright/test` must exactly match the locked nixpkgs
`playwright-driver.version`. When updating nixpkgs, check its driver version and
update `package.json` and `bun.lock` together; Renovate's npm Playwright updates
are disabled to avoid browser/driver mismatches.

`playwright.config.ts` runs `tests/*.e2e.ts` on desktop Chrome and Pixel 7
emulation, retaining traces on failure. The starter browser smoke test renders
the sample CLI greeting; replace it with application-level navigation and
assertions when adding a web app. Unit tests remain under `bun test`.
