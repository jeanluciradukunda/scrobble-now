#!/usr/bin/env bash
# Flags any ${{ inputs.* }} or ${{ github.event.* }} expression that is not the whole value of a key: line (env: or with:),
# so free-text inputs reach shell through env rather than being pasted into a script.
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
