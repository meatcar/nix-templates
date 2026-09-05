#!/usr/bin/env bash
# Exercise exported templates, with an isolated login profile for each project.
# shellcheck disable=SC2016 # Assertions expand in the clean child shell.
set -euo pipefail
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
scratch="$(mktemp -d)"
trap 'rm -rf "$scratch"' EXIT
nix_bin="$(command -v nix)"
for template in flake-basic flake-modules; do
  cmp "$repo_root/.agents/setup" "$repo_root/templates/$template/.agents/setup"
  cmp "$repo_root/.agents/resume" "$repo_root/templates/$template/.agents/resume"
  project="$scratch/$template"
  "$nix_bin" flake new --template "git+file:$repo_root#$template" "$project"
  # Nix template export does not preserve executable bits.
  chmod +x "$project/.agents/setup" "$project/.agents/resume"
  home="$scratch/home-$template"
  mkdir -p "$home/.config/nix"
  ln -s "$HOME/.nix-profile" "$home/.nix-profile"
  cp "$HOME/.config/nix/nix.conf" "$home/.config/nix/nix.conf"
  # Probe values outside PATH, plus exactly-once activation in nested shells.
  cat >> "$project/.envrc" <<'EOF'
export AMP_TEST_VALUE=complete-environment
export NODE_PATH="$PWD/node_modules"
export AMP_TEST_ACTIVATIONS=$((${AMP_TEST_ACTIVATIONS:-0} + 1))
EOF
  (
    cd "$project"
    for run in 1 2; do
      echo "test: $template setup run $run"
      time env -u DIRENV_DIR -u DIRENV_DIFF -u IN_NIX_SHELL HOME="$home" .agents/setup
    done
    [[ "$(grep -Fc '# Amp Nix environment:' "$home/.bash_profile")" == 1 ]]
    env -i HOME="$home" USER="$(id -un)" PATH=/usr/bin:/bin /bin/bash -lc '
      set -eu
      [[ "$IN_NIX_SHELL" == impure ]]
      [[ "$AMP_TEST_VALUE" == complete-environment ]]
      [[ "$NODE_PATH" == "$PWD/node_modules" ]]
      [[ "$AMP_TEST_ACTIVATIONS" == 1 ]]
      [[ "$(command -v bun)" == /nix/store/* ]]
      /bin/bash -lc '\''[[ "$AMP_TEST_ACTIVATIONS" == 1 ]]'\''
      .agents/resume
      if [[ -f package.json ]]; then bun test; fi
      echo "PASS: clean login environment and nested activation"
    '
    mkdir subdirectory
    (
      cd subdirectory
      env -i HOME="$home" USER="$(id -un)" PATH=/usr/bin:/bin /bin/bash -lc \
        '[[ "$AMP_TEST_VALUE" == complete-environment ]]'
    )
    # Evaluate every output. The devshell was already built during setup.
    # treefmt's build check creates a Git commit, which Amp's system-wide
    # signing configuration cannot sign inside a Nix build environment.
    "$nix_bin" flake check --no-build
  )
  (
    cd "$scratch"
    env -i HOME="$home" USER="$(id -un)" PATH=/usr/bin:/bin /bin/bash -lc \
      '[[ -z "${AMP_TEST_VALUE:-}" && -z "${AMP_NIX_ENV_ROOT:-}" ]]'
  )
  echo "PASS: $template setup is idempotent and repository-scoped"
done
