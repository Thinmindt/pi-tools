#!/bin/bash
# The gates every commit must pass, in the order that fails fastest.
set -euo pipefail
cd "$(dirname "$0")/.."

shellcheck=(uvx --from shellcheck-py==0.11.0.1 shellcheck)
codespell=(uvx codespell==2.4.3)
ruff=(uvx ruff@0.14.0)
files() { git ls-files -z --cached --others --exclude-standard "$@"; }

bash scripts/check_private.sh
files '*.json' | xargs -0 -n1 python3 -m json.tool >/dev/null
files '*.sh' | xargs -0 "${shellcheck[@]}"
"${ruff[@]}" check .
"${ruff[@]}" format --check .
files | xargs -0 "${codespell[@]}"
echo "all checks passed"
