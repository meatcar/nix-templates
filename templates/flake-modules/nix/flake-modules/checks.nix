{
  perSystem =
    {
      pkgs,
      inputs',
      ...
    }:
    let
      bun2nix = inputs'.bun2nix.packages.default;
      bunNix = pkgs.runCommand "bun-dependencies.nix" { nativeBuildInputs = [ bun2nix ]; } ''
        bun2nix --lock-file ${../../bun.lock} --output-file "$out"
      '';
      bunDeps = bun2nix.fetchBunDeps { inherit bunNix; };
      check =
        name: command:
        pkgs.stdenv.mkDerivation {
          name = "${name}-check";
          src = pkgs.lib.cleanSource ../..;
          inherit bunDeps;
          nativeBuildInputs = [
            bun2nix.hook
            pkgs.autoPatchelfHook
          ];
          buildInputs = [ pkgs.stdenv.cc.cc.lib ];
          bunInstallFlags = [
            "--linker=isolated"
            "--backend=copyfile"
            "--frozen-lockfile"
          ];
          dontUseBunBuild = true;
          dontRunLifecycleScripts = true;
          PLAYWRIGHT_BROWSERS_PATH = pkgs.playwright-driver.browsers;
          PLAYWRIGHT_SKIP_VALIDATE_HOST_REQUIREMENTS = "true";
          FONTCONFIG_FILE = pkgs.makeFontsConf { fontDirectories = [ pkgs.dejavu_fonts ]; };
          # NOTE: Nix verifies tarball hashes before ELF patching invalidates Fallow signatures.
          FALLOW_SKIP_BINARY_VERIFY = "1";
          CI = "true";
          buildPhase = ''
            export HOME="$TMPDIR/home"
            mkdir -p "$HOME"
            chmod -R u+w node_modules
            autoPatchelf node_modules
            ${command}
          '';
          installPhase = ''
            touch "$out"
          '';
        };
    in
    {
      checks = {
        typecheck = check "typecheck" "bun run typecheck";
        lint = check "lint" "bun run lint";
        unit = check "unit" "bun test";
        e2e = check "e2e" "bun run test:e2e";
      };
    };
}
