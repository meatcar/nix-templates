{ inputs, ... }:
{
  imports = [
    inputs.flake-root.flakeModule
    inputs.treefmt-nix.flakeModule
  ];
  perSystem =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    {
      treefmt.config = {
        inherit (config.flake-root) projectRootFile;
        package = pkgs.treefmt;
        # treefmt walks git when the tree is a repo, and the whole directory when it
        # is not -- which a freshly `nix flake init`ed project is. Without these it
        # reformats node_modules on the first `check`.
        settings.global.excludes = [
          "node_modules/**"
          "coverage/**"
          "dist/**"
          "test-results/**"
          "playwright-report/**"
          "playwright/.cache/**"
          ".direnv/**"
          "*.lock"
          "*.lockb"
          "flake.lock"
        ];
      };
      formatter = config.treefmt.build.wrapper;
      checks = lib.mkIf config.treefmt.flakeCheck {
        treefmt = lib.mkForce (
          (config.treefmt.build.check config.treefmt.projectRoot).overrideAttrs {
            GIT_CONFIG_NOSYSTEM = "1";
          }
        );
      };
      treefmt.config.programs = {
        ## Nix
        # format nix files
        nixfmt.enable = true;
        # remove unused nix variables (skip with `# deadnix: skip`)
        deadnix.enable = true;
        # highlight antipaterns in nix code
        statix.enable = true;
        ## Everything else
        oxfmt.enable = true;
      };
    };
}
