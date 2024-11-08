{...}: {
  perSystem = {
    config,
    pkgs,
    ...
  }: {
    treefmt.config = {
      inherit (config.flake-root) projectRootFile;
      package = pkgs.treefmt;
    };
    formatter = config.treefmt.build.wrapper;
    treefmt.config.programs = {
      alejandra.enable = true;
    };
    pre-commit.check.enable = true;
    pre-commit.settings = {
      hooks = {
        treefmt.enable = true;
      };
    };
  };
}
