# Bun + Nix modules

Run `nix develop` or approve `.envrc` with `direnv allow`, then `bun install`.
Check the project with `bun test`, `bun run check`, and `nix flake check`.
Commit `flake.lock` and `bun.lock`. This template targets x86_64 Linux.

For disposable environments, add `github:meatcar/nix-templates#sandbox` with
`nix flake init -t`, then follow `.agents/sandbox/AGENTS.md`.

## CI and safe auto-merge

`.github/workflows/ci.yml` calls the shared workflow:

```yaml
jobs:
  check:
    name: check
    uses: meatcar/nix-templates/.github/workflows/bun-nix-check.yml@771f23227e8d30e76ae1702f367fafd5d920e53e # main
```

Keep both job names `check`. The exact required status-check context is
**`check / check`**, not `check` or `CI`. Pin to a full commit SHA; the `# main`
comment lets Renovate track and propose updates to that pin. The called workflow
checks out the consumer, runs all commands in its Nix devshell, and needs only
`contents: read` permission. Commit both lockfiles before opening a PR.

CI runs frozen Bun installation, `bun run check`, `bun test`, and `nix flake check`.
It then runs `bun run build` and `bun run test:e2e` only if those scripts exist in
`package.json`. Use these fixed names; projects using `build:html` can add a
`build` alias. `test:e2e` should test the preceding build without rebuilding it.
Failures upload `test-results/` as `playwright-traces` for seven days.

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
`Default branch: CI must pass`, requiring `check / check` from GitHub Actions
(integration 15368), strict up-to-date checks, and an always-on repository-admin
bypass (RepositoryRole 5). Only a successful ruleset write enables **Allow
auto-merge**. Rerunning updates the same ruleset; it does not alter other rulesets
or request auto-merge on individual PRs. Review any older branch protections or
rulesets that still require the former `check` context before migrating.

Once published, add `github>meatcar/renovate-config:automerge` to `extends` in
`.renovaterc.jsonc` to opt into the shared auto-merge policy. It is not enabled
here because the preset is being added separately. The existing local
minor/patch auto-merge rule remains; the ruleset is the merge gate.

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
