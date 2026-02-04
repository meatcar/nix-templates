{...}: {
  perSystem = {
    config,
    pkgs,
    inputs',
    ...
  }: {
    treefmt.config = {
      inherit (config.flake-root) projectRootFile;
      package = pkgs.treefmt;
    };
    formatter = config.treefmt.build.wrapper;
    treefmt.config.programs = {
      ## Nix
      # format nix files
      nixfmt.enable = true;
      # remove unused nix variables (skip with `# deadnix: skip`)
      deadnix.enable = true;
      # highlight antipaterns in nix code
      statix.enable = true;
      ## Everything else
      prettier.enable = true;
    };
    pre-commit.check.enable = true;
    pre-commit.settings = {
      hooks = {
        treefmt.enable = true;
        ess = {
          enable = true;
          name = "ess";
          package = inputs'.ess.packages.default;
          entry = "ess --sample-file=.env.sample";
          pass_filenames = false;
        };
      };
    };
  };
}
