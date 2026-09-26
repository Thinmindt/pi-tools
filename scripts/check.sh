#!/bin/bash
# The gates every commit must pass, in the order that fails fastest.
set -euo pipefail
cd "$(dirname "$0")/.."

SHELLCHECK="uvx --from shellcheck-py==0.11.0.1 shellcheck"
CODESPELL="uvx codespell==2.4.3"
RUFF="uvx ruff@0.14.0"

bash scripts/check_private.sh
for json in $(git ls-files '*.json'); do
    python3 -m json.tool "$json" >/dev/null
done
# shellcheck disable=SC2046
$SHELLCHECK $(git ls-files '*.sh')
$RUFF check .
$RUFF format --check .
git ls-files -z | xargs -0 $CODESPELL
echo "all checks passed"
