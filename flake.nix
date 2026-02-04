{
  description = "meatcar's nix flake templates";

  outputs = {self}: {
    templates = {
      flake-basic = {
        path = ./basic;
        description = "A basic project structure";
      };
      flake-modules = {
        path = ./flake-modules;
        description = "A project structure that uses flake modules";
      };
    };

    defaultTemplate = self.templates.flake-modules;
  };
}
