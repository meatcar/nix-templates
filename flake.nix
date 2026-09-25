{
  description = "meatcar's nix flake templates";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-26.05";
    basic = {
      url = "path:./templates/flake-basic";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    modules = {
      url = "path:./templates/flake-modules";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-parts.follows = "basic/flake-parts";
    };
  };

  outputs =
    {
      self,
      basic,
      modules,
      nixpkgs,
      ...
    }:
    let
      sandboxTests = import ./tests {
        pkgs = nixpkgs.legacyPackages.x86_64-linux;
        inherit self basic modules;
      };
    in
    {
      devShells.x86_64-linux.default = nixpkgs.legacyPackages.x86_64-linux.mkShell {
        packages = with nixpkgs.legacyPackages.x86_64-linux; [
          bun
          shellcheck
        ];
      };

      checks.x86_64-linux =
        nixpkgs.lib.mapAttrs' (name: value: {
          name = "flake-basic-${name}";
          inherit value;
        }) basic.checks.x86_64-linux
        // nixpkgs.lib.mapAttrs' (name: value: {
          name = "flake-modules-${name}";
          inherit value;
        }) modules.checks.x86_64-linux
        // {
          sandbox = sandboxTests.check;
        };

      packages.x86_64-linux.test-sandbox = sandboxTests.runner;
      apps.x86_64-linux.test-sandbox = {
        type = "app";
        program = "${sandboxTests.runner}/bin/test-sandbox";
        meta.description = "Run offline template integration tests";
      };
      packages.x86_64-linux.test-sandbox-cold = sandboxTests.coldRunner;
      apps.x86_64-linux.test-sandbox-cold = {
        type = "app";
        program = "${sandboxTests.coldRunner}/bin/test-sandbox-cold";
        meta.description = "Test live sandbox bootstrap with an empty Nix store";
      };

      formatter.x86_64-linux = modules.formatter.x86_64-linux;

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
