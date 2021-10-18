{
  description = "meatcar's nix flake templates";

  outputs = { self }: {
    templates = {
      direnv-tmux-project = {
        path = ./direnv-tmux-project;
        description = "A project structure that uses direnv and tmux";
      };

      default = self.templates.direnv-tmux-project;
    };
  };
}
