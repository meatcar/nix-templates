{
  description = "meatcar's nix flake templates";

  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-26.05";

  outputs =
    { self, nixpkgs }:
    {
      devShells.x86_64-linux.default = nixpkgs.legacyPackages.x86_64-linux.mkShell {
        packages = with nixpkgs.legacyPackages.x86_64-linux; [
          bun
          shellcheck
        ];
      };

      templates = {
        flake-basic = {
          path = ./templates/flake-basic;
          description = "A basic project structure";
        };
        flake-modules = {
          path = ./templates/flake-modules;
          description = "A project structure that uses flake modules";
        };
      };

      defaultTemplate = self.templates.flake-modules;
    };
}
