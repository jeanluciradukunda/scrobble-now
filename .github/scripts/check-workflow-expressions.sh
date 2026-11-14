#!/usr/bin/env bash
# Free-text workflow inputs and event fields must reach shell through env:, never as ${{ }} inside a run script.
set -euo pipefail
[ $# -gt 0 ] || set -- .github/workflows/*.yml
status=0
for file in "$@"; do
  while IFS= read -r hit; do
    line="${hit#*:}"
    if ! [[ "$line" =~ ^[[:space:]]*[A-Za-z_][A-Za-z0-9_-]*:[[:space:]]*\$\{\{[^}]*\}\}[[:space:]]*$ ]]; then
      echo "::error file=$file::${hit%%:*}: expression from inputs or github.event used outside an env or with value: ${line#"${line%%[![:space:]]*}"}"
      status=1
    fi
  done < <(grep -nE '\$\{\{[[:space:]]*(inputs|github\.event)\.' "$file" || true)
done
exit $status
