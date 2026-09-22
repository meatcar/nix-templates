{
  description = "meatcar's nix flake templates";

  outputs =
    { self }:
    {
      templates = {
        flake-basic = {
          path = ./templates/flake-basic;
          description = "A basic project structure";
        };
        flake-modules = {
          path = ./templates/flake-modules;
          description = "A project structure that uses flake modules";
        };
        sandbox = {
          path = ./templates/sandbox;
          description = "Task-based sandbox setup layered onto a Nix and direnv project";
          welcomeText = ''
            Run `chmod +x .agents/setup .agents/resume`, then customize `.agents/Taskfile.yml`.
            See `.agents/README.md` for requirements and lifecycle behavior.
          '';
        };
      };

      defaultTemplate = self.templates.flake-modules;
    };
}
