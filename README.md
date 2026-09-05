# Nix templates

Both templates include executable Amp orb lifecycle scripts. The default is
`flake-modules`, a Bun/TypeScript project with flake-parts and treefmt.
`flake-basic` provides a smaller Bun development shell.

```sh
# In an empty project directory:
nix flake init --template github:meatcar/nix-templates#flake-modules
# Or: nix flake init --template github:meatcar/nix-templates#flake-basic
chmod +x .agents/setup .agents/resume
git add .
git add -f .envrc # Amp's local Git excludes can match .env*
.agents/setup
```

Nix must already be installed to run `nix flake init`. To bootstrap an orb whose
repository has no files yet, copy the chosen directory from `templates/` into
that repository with `cp -a`, including hidden files, then run `.agents/setup`.
Nix template export drops executable bits, so the `chmod` step above is required
before committing the generated project for Amp to use.

## Orb lifecycle

- `.agents/setup` installs single-user Nix if absent, enables flakes, disables
  sandbox namespaces, installs direnv, allows `.envrc`, and loads the default
  development shell. If `package.json` exists, it installs Bun dependencies,
  using a frozen lockfile whenever `bun.lock` or `bun.lockb` exists.
- Setup adds one repository-scoped, recursion-guarded hook to `~/.bash_profile`.
  New noninteractive login shells in the project or its subdirectories export
  the complete `.envrc` environment, including Nix variables, shell hooks,
  `NODE_PATH`, and project-local binary paths. No nested `nix develop` process
  wraps Amp or its services. The current agent process is not restarted.
- `.agents/resume` checks that Nix remains available. It does not install
  dependencies, start services, or authenticate users.
- `.envrc` remains the environment entry point. Keep dependency/tool changes in
  the flake and `.envrc`, not in a second set of setup PATH exports. Re-run setup
  after changing `.envrc` to approve it for direnv.

Commit the generated `flake.lock` and Bun lockfile in consuming projects. This
template repository ignores its own `flake.lock` so template inputs resolve at
creation time. Keep `.agents/setup` and `.agents/resume` executable and tracked.
The templates ignore generated `.amp/portals/` metadata, not `.agents/`.

The scripts target non-root Debian-based x86_64 Linux orbs with curl and sudo,
matching the current template systems. First setup needs network access to Nix
and package registries. No project pre-setup script or secrets are required.
Do not put user authentication in setup, since Amp snapshots may be shared.
Add authentication to resume only if the consuming application needs it.

No server is declared because neither template contains a web application.
Once one exists, declare it in `.amp/services.yaml` and start it with
`amp orb services ensure`. Services inherit the login-shell environment.

## Verification

```sh
.agents/setup
.agents/setup
direnv exec . shellcheck .agents/setup .agents/resume tests/orb-setup.sh
direnv exec . bash tests/orb-setup.sh
```

The integration test exports each template, runs setup twice with an isolated
home profile, checks a clean `env -i ... bash -lc` environment, nested-shell
activation, subdirectories and unrelated directories, runs resume, Bun tests
where present, and `nix flake check --no-build`. Setup already builds the shell.
The test does not build treefmt's check, which creates an internal Git commit
and cannot use Amp's system-wide signing helper inside a Nix build.
Template lifecycle files are standalone
copies, checked against the root scripts to prevent drift.

The login-shell integration follows `alipes-inc/alipes24`. Its Amp project
`dnka/alipes24` has no project-level pre-setup script. Application-specific
secrets, dependency caches, and services from that project are not copied here.
