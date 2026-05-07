## Codebase: Direnv + Nix + Bun

## Layout:

```
flake.nix           # inputs only.
.envrc              # environment init
nix/flake-modules/  # flake parts
  /devshell.nix     # development shell.
  /treefmt.nix      # single master formatter.
```

## Principles:

- Apply Red/Green TDD.
- Use Conventional Commits with consistent scopes. Short titles, descriptive, and non-repetitive.
- Commits should be atomic, testable, logically distinct.

## Commands

Repo root:

- `direnv exec .`: run commands
- `nix fmt`: format
- `nix flake check`: validate flake outputs.

Ask before network or out-of-workspace actions.

## Nix

- Use `inputs'.nixpkgs-unstable.legacyPackages` only for intentional unstable
  packages.

Run `nix flake check` to enforce via `treefmt-nix`:

- Nix: `nixfmt`
- Nix cleanup/lint: `deadnix`, `statix`
- Other supported files: `oxfmt`
- Other flake checks.

Run `nix fmt` after source edits.

## Bun / Typescript

See `./node_modules/bun-types/CLAUDE.md`

Maximal code style/quality is enforced via `bun check` that runs:

- `bun format`: `treefmt`
- `bun lint`:
  - `oxlint`
    - Type aware,
    - Categories `correctness`, `suspicious`, and `perf` error.
  - `fallow`: duplicates, code health
