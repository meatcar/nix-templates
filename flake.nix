{
  description = "meatcar's nix flake templates";

  outputs =
    { self }:
    {
      templates = {
        flake-basic = {
          path = ./templates/nix/flake-basic;
          description = "A basic project structure";
        };
        flake-modules = {
          path = ./templates/nix/flake-modules;
          description = "A project structure that uses flake modules";
        };
      };

      defaultTemplate = self.templates.flake-modules;
    };
}
