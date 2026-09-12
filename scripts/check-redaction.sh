#!/usr/bin/env bash
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

fail=0

check() {
  local name="$1" pattern="$2"
  local hits
  hits=$(git ls-files -z | xargs -0 grep -nEI "$pattern" | cut -d: -f1,2 || true)
  if [ -n "$hits" ]; then
    echo "BLOCKED: $name" >&2
    echo "$hits" >&2
    fail=1
  fi
}

check "AWS account ID" '\b[0-9]{12}\b'
check "AWS organisation ID"    '\bo-[a-z0-9]{10,32}\b'
check "Organizational unit ID" '\bou-[a-z0-9]{4,32}-[a-z0-9]{8,32}\b'
check "AWS key or unique ID"   '\b(AKIA|ASIA|AROA|AIDA)[A-Z0-9]{16}\b'
check "Identity Center"        '\b(d-[0-9a-f]{10}|[a-z0-9-]+\.awsapps\.com)\b'
check "Email address" '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}'

exit "$fail"