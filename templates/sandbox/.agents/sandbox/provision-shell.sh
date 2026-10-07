#!/usr/bin/env bash
# Install shell hooks that load the devshell in future shells.
# Takes the Task executable path as its first argument.
set -euo pipefail

agent_env="$HOME/.sandbox-env.sh"
printf "export PATH=%q:\$PATH\n" "$(dirname "$1"):$HOME/.nix-profile/bin" > "$agent_env"
cat >> "$agent_env" << 'EOF'
command -v direnv >/dev/null 2>&1 && eval "$(direnv hook bash)"
EOF

if ! grep -Fq '.sandbox-env.sh' "$HOME/.bashrc" 2> /dev/null; then
  cat >> "$HOME/.bashrc" << 'EOF'

[ -f "$HOME/.sandbox-env.sh" ] && . "$HOME/.sandbox-env.sh"
EOF
fi

marker="# sandbox environment: $PWD"
if ! grep -Fqx "$marker" "$HOME/.bash_profile" 2> /dev/null; then
  {
    printf "\n%s\nif [[ \$PWD == %q || \$PWD == %q/* ]]; then\n" "$marker" "$PWD" "$PWD"
    cat << 'EOF'
  [ -f "$HOME/.sandbox-env.sh" ] && . "$HOME/.sandbox-env.sh"
  if command -v direnv >/dev/null 2>&1; then
    direnv allow . >/dev/null 2>&1
    eval "$(direnv export bash 2>/dev/null)"
  fi
fi
EOF
  } >> "$HOME/.bash_profile"
fi
