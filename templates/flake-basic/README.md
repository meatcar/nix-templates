# Bun + Nix

After `nix flake init`, run `chmod +x .agents/setup .agents/resume` and commit
those mode changes. Nix template export does not preserve executable bits.

Run `.agents/setup` in a fresh Amp orb. It installs Nix and direnv, loads
`.envrc`, and persists the complete environment for new login shells in this
checkout. Run it again after changing `.envrc`. `.agents/resume` checks Nix
without installing anything.

Use `direnv exec . <command>` locally or `nix develop --command <command>` in CI.
Commit `flake.lock` and any Bun lockfile. Keep `.agents/setup` and
`.agents/resume` executable. Setup installs dependencies when `package.json`
exists, using a frozen lockfile if available.

This template targets non-root x86_64 Linux orbs. Initial setup needs network
access. No secrets, project pre-setup script, or web services are required.
If you add a server, declare it in `.amp/services.yaml` and run
`amp orb services ensure`. Authenticate users in resume, not snapshot setup.
