{
  perSystem = {
    pkgs,
    config,
    ...
  }: {
    legacyPackages = pkgs;
    devShells.default = pkgs.mkShell {
      name = "changeme";
      inputsFrom = [
        config.pre-commit.devShell
        config.flake-root.devShell
        config.treefmt.build.devShell
      ];
      buildInputs = with pkgs;
        (builtins.attrValues config.treefmt.build.programs)
        ++ [
          nil # for nix completion
        ]
        ++ [ bun ];
    };
  };
}
