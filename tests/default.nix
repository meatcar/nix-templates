{
  pkgs,
  self,
  basic,
  modules,
}:
let
  inherit (pkgs) lib;
  python = pkgs.python3.withPackages (ps: [
    ps.pytest
    ps.pyyaml
  ]);
  tools = pkgs.buildEnv {
    name = "sandbox-test-tools";
    paths = with pkgs; [
      bashInteractive
      coreutils
      curl
      direnv
      gitMinimal
      gnugrep
      gnused
      gnutar
      gzip
      nix
      xz
    ];
  };
  closure = pkgs.closureInfo {
    rootPaths = [
      tools
      self.outPath
      pkgs.go-task
      pkgs.cacert
      basic.inputs.flake-parts.inputs.nixpkgs-lib.outPath
      basic.devShells.${pkgs.stdenv.hostPlatform.system}.default
      modules.devShells.${pkgs.stdenv.hostPlatform.system}.default
    ]
    ++ map (input: input.outPath) (lib.attrValues basic.inputs ++ lib.attrValues modules.inputs);
  };
  config = pkgs.writeText "sandbox-test-config.json" (
    builtins.toJSON {
      templates = {
        flake-basic = "basic";
        flake-modules = "modules";
      };
      source = self.outPath;
      closure = toString closure;
      tools = toString tools;
      task = "${pkgs.go-task}/bin/task";
      taskVersion = pkgs.go-task.version;
      certificates = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
    }
  );
  runner = pkgs.writeShellApplication {
    name = "test-sandbox";
    runtimeInputs = [
      python
      pkgs.bubblewrap
      pkgs.coreutils
    ];
    text = ''
      export SANDBOX_TEST_CONFIG=${config}
      exec python -m pytest -q -p no:cacheprovider ${./.} "$@"
    '';
  };
in
{
  inherit runner;
  check = pkgs.runCommand "sandbox-integration-tests" { } ''
    ${runner}/bin/test-sandbox
    touch "$out"
  '';
}
