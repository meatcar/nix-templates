# Bun + Nix

Run `nix develop` or approve `.envrc` with `direnv allow`. Commit `flake.lock`
and any Bun lockfile. This template targets x86_64 Linux.

For disposable environments, add `github:meatcar/nix-templates#sandbox` with
`nix flake init -t`, then follow `.agents/README.md`.
