{ inputs, ... }:
{
  perSystem =
    { system, ... }:
    {
      _module.args.pkgs = import inputs.nixpkgs {
        inherit system;
        overlays = [
          # TODO: drop Bun-before-bun2nix ordering once nixpkgs ships bun >= 1.4.4 (CVE-2026-111497).
          # see https://github.com/NixOS/nixpkgs/pull/574334
          # see https://github.com/NixOS/nixpkgs/pull/577354
          (import ../overlays/bun-cve-2026-111497.nix)
          inputs.bun2nix.overlays.default
        ];
      };
    };
}
