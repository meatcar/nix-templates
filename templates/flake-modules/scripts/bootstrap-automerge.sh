#!/usr/bin/env bash
set -euo pipefail

if (( $# > 1 )); then
  echo "Usage: bash scripts/bootstrap-automerge.sh [OWNER/REPO]" >&2
  exit 1
fi

repo=${1:-$(gh repo view --json nameWithOwner --jq .nameWithOwner)}
ruleset_id=$(gh api "repos/$repo/rulesets?includes_parents=false&per_page=100" \
  --paginate --jq '.[] | select(.name == "Default branch: CI must pass") | .id')

case "$ruleset_id" in
  *[!0-9]*)
    echo "Multiple matching rulesets found. Resolve duplicates before rerunning." >&2
    exit 1
    ;;
esac

endpoint="repos/$repo/rulesets"
method=POST
if [[ -n "$ruleset_id" ]]; then
  endpoint+="/$ruleset_id"
  method=PUT
fi

gh api "$endpoint" --method "$method" --input - > /dev/null <<'JSON'
{
  "name": "Default branch: CI must pass",
  "target": "branch",
  "enforcement": "active",
  "conditions": {"ref_name": {"include": ["~DEFAULT_BRANCH"], "exclude": []}},
  "bypass_actors": [
    {"actor_id": 5, "actor_type": "RepositoryRole", "bypass_mode": "always"}
  ],
  "rules": [{"type": "required_status_checks", "parameters": {
    "strict_required_status_checks_policy": true,
    "required_status_checks": [{"context": "check", "integration_id": 15368}]
  }}]
}
JSON

gh api "repos/$repo" --method PATCH --input - > /dev/null <<'JSON'
{"allow_auto_merge": true}
JSON

echo "Required check 'check' configured; auto-merge enabled for $repo."
