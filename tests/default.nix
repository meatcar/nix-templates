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
    ps.pytest-xdist
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
      nix = toString pkgs.nix;
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
      exec python -m pytest -q -n 2 --dist loadgroup -p no:cacheprovider -m 'not cold' ${./.} "$@"
    '';
  };
  coldRoot = pkgs.runCommand "sandbox-cold-root" { } ''
    mkdir -p "$out"/{bin,usr,etc/ssl/certs,root,nix,tmp,proc,dev,work}
    cp ${pkgs.pkgsStatic.busybox}/bin/busybox "$out/bin/"
    for command in $(${pkgs.pkgsStatic.busybox}/bin/busybox --list); do
      [ "$command" = busybox ] || ln -s busybox "$out/bin/$command"
    done
    cp --remove-destination -L ${pkgs.pkgsStatic.coreutils}/bin/* "$out/bin/"
    cp ${pkgs.pkgsStatic.bash}/bin/bash "$out/bin/"
    cp ${lib.getBin pkgs.pkgsStatic.curl}/bin/curl "$out/bin/"
    ln -s ../bin "$out/usr/bin"
    printf 'root:x:0:0:root:/root:/bin/bash\n' > "$out/etc/passwd"
    printf 'root:x:0:\n' > "$out/etc/group"
    touch "$out/etc/resolv.conf" "$out/etc/ssl/certs/ca-certificates.crt"
  '';
in
{
  inherit runner;
  coldRunner = pkgs.writeShellApplication {
    name = "test-sandbox-cold";
    text = ''
      exec ${runner}/bin/test-sandbox -n 0 -m cold --cold-root=${coldRoot} "$@"
    '';
  };
  check = pkgs.runCommand "sandbox-integration-tests" { } ''
    ${pkgs.shellcheck}/bin/shellcheck ${../templates/sandbox/.agents}/{setup,resume,sandbox/*.sh}
    ${runner}/bin/test-sandbox
    touch "$out"
  '';
}
