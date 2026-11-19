#!/usr/bin/env bash
# Run the registered suite without retaining earlier files' mock frames.
# LUAJIT may select a local binary; other arguments go to the test harness.
set -euo pipefail
cd "$(dirname "$0")/../.."
luajit_bin=${LUAJIT:-luajit}
listing=$("$luajit_bin" tests/run.lua --list)
test -n "$listing"
mapfile -t files <<< "$listing"
for file in "${files[@]}"; do
  [[ "$file" =~ ^[a-z0-9_]+$ ]] || { echo "Invalid test name: $file" >&2; exit 1; }
  "$luajit_bin" tests/run.lua "$file.lua" "$@"
done
printf '\nAll %s registered test files passed in separate LuaJIT processes.\n' "${#files[@]}"
