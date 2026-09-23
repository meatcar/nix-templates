{
  description = "changeme";

  inputs = {
    # see docs at https://flake.parts/
    flake-parts.url = "github:hercules-ci/flake-parts";
    nixpkgs.url = "github:nixos/nixpkgs/nixos-26.05";
  };

  outputs =
    inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      flake = { };
      systems = [ "x86_64-linux" ];
      perSystem =
        { pkgs, config, ... }:
        {
          legacyPackages = pkgs;
          devShells.default = pkgs.mkShell {
            # TODO: change to project name
            name = "devshell";
            buildInputs = with pkgs; [ bun ];
          };
          checks.devshell = config.devShells.default.overrideAttrs (old: {
            name = "devshell-check";
            nativeBuildInputs = old.nativeBuildInputs ++ [ pkgs.python3Packages.pytest ];
            buildPhase = ''
              cp -r ${./.} project
              chmod -R u+w project
              cd project
              export HOME="$TMPDIR/home"
              mkdir -p "$HOME"
              eval "$shellHook"
              pytest -q tests/test_devshell.py
              touch "$out"
            '';
          });
        };
    };
}
