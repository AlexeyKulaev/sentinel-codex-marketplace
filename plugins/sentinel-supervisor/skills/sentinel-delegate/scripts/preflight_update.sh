#!/usr/bin/env bash
set -euo pipefail

RUN_DIR=".codex/sentinel-run"
mkdir -p "$RUN_DIR"

echo "--- checking sentinel binary ---"

if ! command -v sentinel >/dev/null 2>&1; then
  echo "status=missing"
  echo "sentinel binary not found in PATH"
  echo "install: pipx install git+https://github.com/Makson179/Sentinel.git"
  exit 127
fi

echo "status=found"
command -v sentinel | tee "$RUN_DIR/sentinel.path.txt"

echo
echo "--- environment checks ---"
python3 --version 2>&1 | tee "$RUN_DIR/python.version.txt" || true
git --version 2>&1 | tee "$RUN_DIR/git.version.txt" || true
codex --version 2>&1 | tee "$RUN_DIR/codex.version.txt" || true

echo
echo "--- codex app-server schema check ---"
codex app-server generate-json-schema --experimental --out /tmp/sentinel-schema-check \
  > "$RUN_DIR/codex.schema.log" 2>&1 || true
cat "$RUN_DIR/codex.schema.log"

echo
echo "--- sentinel version before update ---"
sentinel --version | tee "$RUN_DIR/version.before.txt" || true

echo
echo "--- sentinel doctor before update ---"
set +e
sentinel doctor > "$RUN_DIR/doctor.before.txt" 2>&1
DOCTOR_EXIT=$?
set -e

cat "$RUN_DIR/doctor.before.txt"

if [[ "$DOCTOR_EXIT" -ne 0 ]]; then
  echo "sentinel doctor failed before update"
  echo "Not running Sentinel task."
  exit "$DOCTOR_EXIT"
fi

echo
echo "--- update detection ---"

# Temporary heuristic until Sentinel supports a machine-readable update check.
# Recommended future command:
#   sentinel doctor --json
# or:
#   sentinel update --check --json
if grep -Eiq "update available|new version|out of date|outdated|behind" \
  "$RUN_DIR/doctor.before.txt" "$RUN_DIR/version.before.txt"; then

  echo "update_available=true"
  echo "--- running sentinel update ---"
  sentinel update | tee "$RUN_DIR/update.log"

  echo
  echo "--- sentinel version after update ---"
  sentinel --version | tee "$RUN_DIR/version.after.txt" || true

  echo
  echo "--- sentinel doctor after update ---"
  sentinel doctor | tee "$RUN_DIR/doctor.after.txt"
else
  echo "update_available=false"
fi
