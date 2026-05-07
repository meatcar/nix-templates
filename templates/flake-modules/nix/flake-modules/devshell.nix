{
  imports = [
    ./treefmt.nix
  ];
  perSystem =
    {
      pkgs,
      config,
      ...
    }:
    {
      legacyPackages = pkgs;
      devShells.default = pkgs.mkShell {
        # TODO: change to project name
        name = "devshell";
        inputsFrom = [
          config.flake-root.devShell
          config.treefmt.build.devShell
        ];
        buildInputs =
          with pkgs;
          (builtins.attrValues config.treefmt.build.programs)
          ++ [
            nil # nix lsp
          ]
          ++ [ bun ];
      };
    };
}
