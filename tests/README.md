# Template tests

Run from the repository root. Requires x86_64 Linux and unprivileged user namespaces.

```sh
nix flake check -L                           # Offline checks
nix run .#test-sandbox -- -k cleanup          # Filter pytest cases
nix run .#test-sandbox -- -n 0 --durations=10  # Serial, timed
nix run .#test-sandbox-cold                   # Live downloads; empty /nix
```

Cold tests download during setup, then resume offline. They are excluded from
`flake check`.

Quoted project paths trigger a
[Nix 2.34 escaping bug](https://github.com/NixOS/nix/blob/2.34.8/src/nix/develop.cc#L330-L417).
These cases use strict `xfail` until it is fixed.
