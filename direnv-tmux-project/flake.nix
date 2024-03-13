{
  description = "changeme";

  inputs = {
    # see docs at https://flake.parts/
    flake-parts.url = "github:hercules-ci/flake-parts";
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  };

  outputs = inputs @ {flake-parts, ...}:
    flake-parts.lib.mkFlake {inherit inputs;} {
      flake = {};
      systems = ["x86_64-linux"];
      perSystem = {pkgs, ...}: {
        devShells.default = pkgs.mkShell {
          name = "changeme";
          buildInputs = with pkgs; [
            # some
            # packages
            # here
          ];
        };
      };
    };
}
