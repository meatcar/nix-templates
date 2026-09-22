#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
export HOME="$tmp/home with spaces ' \$HOME"
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_CACHE_HOME="$HOME/.cache"
export XDG_DATA_HOME="$HOME/.local/share"
unset DIRENV_DIR DIRENV_DIFF DIRENV_WATCHES
mkdir -p "$HOME/.nix-profile/bin" "$XDG_CONFIG_HOME/direnv"
ln -s "$(command -v nix)" "$HOME/.nix-profile/bin/nix"
mkdir -p "$HOME/.local/share/sandbox/task-v3.48.0"
if [[ "${SANDBOX_TEST_DOWNLOAD_TASK:-0}" != 1 ]]; then
  ln -s "$(command -v task)" "$HOME/.local/share/sandbox/task-v3.48.0/task"
fi

# NOTE: Exercise direnv without downloading each base template's toolchain.
cat > "$XDG_CONFIG_HOME/direnv/direnvrc" << 'EOF'
use_flake() { export SANDBOX_TEST_SHELL=ready; }
EOF

for template in flake-basic flake-modules; do
  repo="$tmp/$template with spaces ' \$HOME"
  mkdir -p "$repo"
  (
    cd "$repo"
    nix flake init -t "path:$root#$template"
    nix flake init -t "path:$root#sandbox"
    cmp "$root/templates/$template/.envrc" .envrc
    cmp "$root/templates/$template/flake.nix" flake.nix
    [[ ! -e .amp && ! -e Taskfile.yml ]]
    printf 'SANDBOX_TEST_DOTENV=initial\n' > .env
    bash .agents/setup
    bash .agents/setup
    bash .agents/resume
    [[ "$(grep -c '^sandbox = false$' "$XDG_CONFIG_HOME/nix/nix.conf")" -eq 1 ]]
    [[ "$(grep -c '^experimental-features = .*nix-command.*flakes' "$XDG_CONFIG_HOME/nix/nix.conf")" -eq 1 ]]
    [[ "$(grep -Fxc "# sandbox environment: $repo" "$HOME/.bash_profile")" -eq 1 ]]
    [[ "$(wc -l < "$HOME/.bashrc")" -eq 2 ]]
    bash --noprofile --norc -ec '
      source "$HOME/.bash_profile"
      [[ "$SANDBOX_TEST_SHELL" == ready && "$SANDBOX_TEST_DOTENV" == initial ]]
      [[ "$(command -v task)" == "$HOME/.local/share/sandbox/"* ]]
      if [[ "$PWD" == *flake-modules* ]]; then
        [[ ":$PATH:" == *":$PWD/node_modules/.bin:"* ]]
      fi
    '
    bash --noprofile --norc -ec '
      source "$HOME/.bashrc"
      _direnv_hook
      [[ "$SANDBOX_TEST_SHELL" == ready && "$SANDBOX_TEST_DOTENV" == initial ]]
    '
    printf '\nexit 19\n' >> .envrc
    direnv allow .
    if bash .agents/resume; then
      echo 'Resume accepted a broken dev shell' >&2
      exit 1
    fi
    cp "$root/templates/$template/.envrc" .envrc
    direnv allow .
    awk '
      /^version:/ { print; print "\nincludes:\n  project: ./project.yml"; next }
      /^  [a-z_]+:$/ { name=$1; sub(/:$/, "", name) }
      /    cmds: \[\]/ { print "    cmds: [{task: project:" name "}]"; next }
      /      - task: deps$/ {
        print "      - task: project:pre_deps"; print; print "      - task: project:post_deps"; next
      }
      { print }
    ' .agents/Taskfile.yml > .agents/custom.yml
    mv .agents/custom.yml .agents/Taskfile.yml
    cat > .agents/project.yml << 'EOF'
version: '3'
tasks:
  before_nix:
    cmds:
      - test ! -e early-auth-fails
      - echo before_nix >> phases
  auth:
    cmds:
      - test "$SANDBOX_TEST_SHELL" = ready
      - echo auth >> phases
  setup_auth:
    cmds:
      - task: auth
      - test "$SANDBOX_LIFECYCLE" = setup
      - touch setup-credential
      - test ! -e auth-fails
      - printf 'SANDBOX_TEST_DOTENV=setup\n' > .env
      - echo setup_auth >> phases
  resume_auth:
    cmds:
      - task: auth
      - test "$SANDBOX_LIFECYCLE" = resume
      - test ! -e auth-fails
      - printf 'SANDBOX_TEST_DOTENV=resume\n' > .env
      - echo resume_auth >> phases
  pre_deps:
    cmds:
      - test "$SANDBOX_TEST_DOTENV" = "$SANDBOX_LIFECYCLE"
      - test -z "${SANDBOX_TEST_REMOVED+x}"
      - echo pre_deps >> phases
  deps:
    cmds:
      - test ! -e deps-fails
      - echo deps >> phases
      - export SANDBOX_TEST_EXPORT=leak
      - test -z "${SANDBOX_TEST_EXPORT+x}"
  post_deps:
    cmds: [echo post_deps >> phases]
  prep:
    cmds: [echo prep >> phases]
  check:
    cmds:
      - test ! -e check-fails
      - echo check >> phases
  ready:
    cmds:
      - echo ready >> phases
      - touch runtime-ready
  outer:
    cmds:
      - test "$SANDBOX_TEST_DOTENV" = stale
      - test "$SANDBOX_TEST_REMOVED" = old
  setup_cleanup:
    cmds:
      - task: outer
      - echo cleanup >> phases
      - test ! -e cleanup-fails
      - rm -f setup-credential
EOF
    project_before="$(sha256sum .agents/Taskfile.yml .agents/project.yml)"
    cp "$root/templates/sandbox/.agents/sandbox/"* .agents/sandbox/
    printf 'SANDBOX_TEST_DOTENV=stale\nSANDBOX_TEST_REMOVED=old\n' > .env
    dump="$(direnv export bash)"
    eval "$dump"
    [[ "$SANDBOX_TEST_DOTENV" == stale ]]
    rm "$HOME/.sandbox-env.sh"
    touch early-auth-fails
    : > phases
    if bash .agents/setup; then
      echo 'Setup accepted failed pre-Nix authentication' >&2
      exit 1
    fi
    [[ ! -e "$HOME/.sandbox-env.sh" && "$(cat phases)" == cleanup ]]
    rm early-auth-fails
    for lifecycle in setup resume; do
      : > phases
      bash ".agents/$lifecycle"
      expected=$'before_nix\nauth\n'"${lifecycle}_auth"$'\npre_deps\ndeps\npost_deps\nprep\ncheck\nready'
      [[ "$lifecycle" != setup ]] || expected+=$'\ncleanup'
      [[ "$(cat phases)" == "$expected" && -f runtime-ready && ! -e setup-credential ]]
      [[ "$SANDBOX_TEST_DOTENV" == stale ]]
      for failure in auth deps check; do
        : > phases
        rm runtime-ready
        touch "$failure-fails"
        if bash ".agents/$lifecycle"; then
          echo "$lifecycle accepted a failed $failure" >&2
          exit 1
        fi
        expected=$'before_nix\nauth'
        [[ "$failure" == auth ]] || expected+=$'\n'"${lifecycle}_auth"$'\npre_deps'
        [[ "$failure" != check ]] || expected+=$'\ndeps\npost_deps\nprep'
        [[ "$lifecycle" != setup ]] || expected+=$'\ncleanup'
        [[ "$(cat phases)" == "$expected" && ! -e runtime-ready && ! -e setup-credential ]]
        rm "$failure-fails"
        touch runtime-ready
      done
    done
    touch cleanup-fails
    : > phases
    if bash .agents/setup; then
      echo 'Setup accepted failed credential cleanup' >&2
      exit 1
    fi
    [[ -e setup-credential && "$(tail -1 phases)" == cleanup ]]
    rm cleanup-fails runtime-ready
    printf '\nexit 19\n' >> .envrc
    direnv allow .
    : > phases
    if bash .agents/setup; then
      echo 'Setup accepted a broken dev shell' >&2
      exit 1
    fi
    [[ ! -e setup-credential && ! -e runtime-ready && "$(cat phases)" == $'before_nix\ncleanup' ]]
    cp "$root/templates/$template/.envrc" .envrc
    direnv allow .
    [[ "$(sha256sum .agents/Taskfile.yml .agents/project.yml)" == "$project_before" ]]
  )
done

cat > "$repo/.agents/Taskfile.yml" << 'EOF'
version: '3'
silent: true
tasks:
  check_proxy:
    cmds:
      - test "${HTTP_PROXY:-}" = "$EXPECTED_HTTP"
      - test "${http_proxy:-}" = "$EXPECTED_HTTP"
      - test "${HTTPS_PROXY:-}" = "$EXPECTED_HTTPS"
      - test "${https_proxy:-}" = "$EXPECTED_HTTPS"
  before_nix:
    cmds: [{task: check_proxy}]
  setup_auth:
    cmds: [{task: check_proxy}]
  resume_auth:
    cmds: [{task: check_proxy}]
  work:
    cmds: [{task: check_proxy}]
  setup_cleanup:
    cmds: [{task: check_proxy}]
EOF
env -u HTTP_PROXY -u HTTPS_PROXY -u http_proxy -u https_proxy \
  -u npm_config_http_proxy -u npm_config_https_proxy \
  bash -e -s -- "$repo" << 'EOF'
    export EXPECTED_HTTP='' EXPECTED_HTTPS=''
    bash "$1/.agents/setup"
    export npm_config_https_proxy=https://npm.example:8443
    export EXPECTED_HTTP="$npm_config_https_proxy" EXPECTED_HTTPS="$npm_config_https_proxy"
    bash "$1/.agents/setup"
    export npm_config_https_proxy=https://resumed-npm.example:9443
    export EXPECTED_HTTP="$npm_config_https_proxy" EXPECTED_HTTPS="$npm_config_https_proxy"
    bash "$1/.agents/resume"
    export npm_config_https_proxy=https://resumed-again.example:8444
    export EXPECTED_HTTP="$npm_config_https_proxy" EXPECTED_HTTPS="$npm_config_https_proxy"
    bash "$1/.agents/resume"
    unset npm_config_https_proxy
    export http_proxy=http://resume-http.example:8081 https_proxy=https://resume-https.example:9444
    export EXPECTED_HTTP="$http_proxy" EXPECTED_HTTPS="$https_proxy"
    bash "$1/.agents/resume"
    export HTTP_PROXY=http://http.example:8080 HTTPS_PROXY=https://https.example:9443
    export http_proxy=http://ignored.example https_proxy=https://ignored.example
    export EXPECTED_HTTP="$HTTP_PROXY" EXPECTED_HTTPS="$HTTPS_PROXY"
    bash "$1/.agents/resume"
EOF

cp "$root/templates/sandbox/.agents/Taskfile.yml" "$repo/.agents/Taskfile.yml"
mkdir "$tmp/without-direnv"
for tool in bash dirname id; do
  ln -s "$(command -v "$tool")" "$tmp/without-direnv/$tool"
done
if PATH="$tmp/without-direnv" bash "$repo/.agents/resume" > "$tmp/missing-direnv.log" 2>&1; then
  echo 'Resume accepted a missing direnv installation' >&2
  exit 1
fi
grep -Fq 'Devshell unavailable; run .agents/setup' "$tmp/missing-direnv.log"
mkdir "$tmp/bin"
cat > "$tmp/bin/curl" << 'EOF'
#!/usr/bin/env bash
touch "$HOME/download-attempted"
printf 'corrupt archive' > "${@: -1}"
EOF
chmod +x "$tmp/bin/curl"
export PATH="$tmp/bin:$PATH"
rm "$HOME/.nix-profile/bin/nix"
if bash "$repo/.agents/resume"; then
  echo 'Resume accepted a missing Nix installation' >&2
  exit 1
fi
[[ ! -e "$HOME/download-attempted" ]]
rm "$HOME/.local/share/sandbox/task-v3.48.0/task"
if bash "$repo/.agents/resume"; then
  echo 'Resume accepted a missing Task installation' >&2
  exit 1
fi
[[ ! -e "$HOME/download-attempted" ]]
if bash "$repo/.agents/setup"; then
  echo 'Setup accepted an invalid Task download' >&2
  exit 1
fi
[[ -e "$HOME/download-attempted" && ! -e "$HOME/.local/share/sandbox/task-v3.48.0/task" ]]

echo 'sandbox tests passed'
