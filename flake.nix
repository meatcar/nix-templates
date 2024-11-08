{
  description = "meatcar's nix flake templates";

  outputs = {self}: {
    templates = {
      flake-basic = {
        path = ./direnv-tmux-project;
        description = "A project structure that uses direnv and tmux";
      };
      flake-modules = {
        path = ./flake-modules;
        description = "A project structure that uses flake modules";
      };
    };

    defaultTemplate = self.templates.flake-modules;
  };
}
