#!/usr/bin/env bash
set -euo pipefail

RUN_DIR=".codex/sentinel-run"
PROJECT_DIR="$(pwd -P)"
mkdir -p "$RUN_DIR"

TASK_FILE=""
MODEL=""
CODER_MOD=""
SUPER_MOD=""
START_OVER=0
CLEAN=0
ADVERSARY=0
PROTECTED_PATHS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --task)
      TASK_FILE="${2:?missing value for --task}"
      shift 2
      ;;
    --model)
      MODEL="${2:?missing value for --model}"
      shift 2
      ;;
    --coder-mod)
      CODER_MOD="${2:?missing value for --coder-mod}"
      shift 2
      ;;
    --super-mod)
      SUPER_MOD="${2:?missing value for --super-mod}"
      shift 2
      ;;
    --start-over)
      START_OVER=1
      shift
      ;;
    --clean)
      CLEAN=1
      shift
      ;;
    --adversary)
      ADVERSARY=1
      shift
      ;;
    --protected-path)
      PROTECTED_PATHS+=("${2:?missing value for --protected-path}")
      shift 2
      ;;
    *)
      echo "unsupported argument: $1"
      echo "Supported: --task --model --coder-mod --super-mod --start-over --clean --adversary --protected-path"
      exit 2
      ;;
  esac
done

if [[ -z "$TASK_FILE" ]]; then
  TASK_FILE="TASK.md"
fi

if [[ ! -f "$TASK_FILE" ]]; then
  echo "task file not found: $TASK_FILE"
  exit 2
fi

if [[ -n "$CODER_MOD" && -z "$SUPER_MOD" ]]; then
  echo "--coder-mod requires --super-mod"
  exit 2
fi

if [[ -z "$CODER_MOD" && -n "$SUPER_MOD" ]]; then
  echo "--super-mod requires --coder-mod"
  exit 2
fi

is_existing_sentinel_run() {
  local pid="$1"

  if ! kill -0 "$pid" 2>/dev/null; then
    return 1
  fi

  local proc_cwd=""
  local proc_cmd=""

  proc_cwd="$(readlink -f "/proc/$pid/cwd" 2>/dev/null || true)"
  proc_cmd="$(tr '\0' ' ' < "/proc/$pid/cmdline" 2>/dev/null || true)"

  [[ "$proc_cwd" == "$PROJECT_DIR" && "$proc_cmd" == *sentinel* ]]
}

PID_FILE="$RUN_DIR/pid"

if [[ -f "$PID_FILE" ]]; then
  OLD_PID="$(cat "$PID_FILE" 2>/dev/null || true)"

  if [[ -n "$OLD_PID" ]] && is_existing_sentinel_run "$OLD_PID"; then
    echo "sentinel already running pid=$OLD_PID"
    exit 0
  fi

  echo "removing stale pid file"
  rm -f "$PID_FILE"
fi

cmd=(sentinel)

# Order follows COMMAND_ORDER.md / tt.md.
cmd+=(--task "$TASK_FILE")

if [[ -n "$MODEL" ]]; then
  cmd+=(--model "$MODEL")
fi

if [[ -n "$CODER_MOD" && -n "$SUPER_MOD" ]]; then
  cmd+=(--coder-mod "$CODER_MOD")
  cmd+=(--super-mod "$SUPER_MOD")
fi

if [[ "$START_OVER" -eq 1 ]]; then
  cmd+=(--start-over)
fi

if [[ "$CLEAN" -eq 1 ]]; then
  cmd+=(--clean)
fi

if [[ "$ADVERSARY" -eq 1 ]]; then
  cmd+=(--adversary)
fi

for path in "${PROTECTED_PATHS[@]}"; do
  cmd+=(--protected-path "$path")
done

date -Is > "$RUN_DIR/started_at.txt"
git status --short > "$RUN_DIR/status.before" 2>/dev/null || true

{
  printf 'argv:'
  printf ' %q' "${cmd[@]}"
  printf '\n'
} > "$RUN_DIR/command.txt"

python3 - "$RUN_DIR/launch.json" \
  "$PROJECT_DIR" \
  "$TASK_FILE" \
  "$MODEL" \
  "$CODER_MOD" \
  "$SUPER_MOD" \
  "$START_OVER" \
  "$CLEAN" \
  "$ADVERSARY" \
  "${PROTECTED_PATHS[@]}" <<'PY'
import json
import sys

out = sys.argv[1]
project_dir = sys.argv[2]
task_file = sys.argv[3]
model = sys.argv[4]
coder_mod = sys.argv[5]
super_mod = sys.argv[6]
start_over = sys.argv[7] == "1"
clean = sys.argv[8] == "1"
adversary = sys.argv[9] == "1"
protected_paths = sys.argv[10:]

data = {
    "project_dir": project_dir,
    "task_file": task_file,
    "model": model or None,
    "coder_mod": coder_mod or None,
    "super_mod": super_mod or None,
    "start_over": start_over,
    "clean": clean,
    "adversary": adversary,
    "protected_paths": protected_paths,
}

with open(out, "w", encoding="utf-8") as f:
    json.dump(data, f, ensure_ascii=False, indent=2)
    f.write("\n")
PY

cat > "$RUN_DIR/context.txt" <<'EOF'
Sentinel is the runtime executor.
Codex plugin is the observer/reporter.
Sentinel writes durable state into `.supervisor/`.
Codex should monitor `.supervisor/*`, git status, and git diff.
EOF

echo "--- launching sentinel ---"
cat "$RUN_DIR/command.txt"

# `&` alone is not enough in Codex/tool environments.
# Use nohup + setsid so the process is not tied to the launching shell/session.
nohup setsid "${cmd[@]}" \
  > "$RUN_DIR/sentinel.log" \
  2> "$RUN_DIR/sentinel.err.log" \
  < /dev/null &

PID="$!"
echo "$PID" > "$PID_FILE"
echo "started sentinel pid=$PID"

echo "--- readiness check ---"

for _ in $(seq 1 30); do
  if ! kill -0 "$PID" 2>/dev/null; then
    echo "status=exited_during_startup"
    echo "--- command ---"
    cat "$RUN_DIR/command.txt" 2>/dev/null || true
    echo "--- stdout ---"
    cat "$RUN_DIR/sentinel.log" 2>/dev/null || true
    echo "--- stderr ---"
    cat "$RUN_DIR/sentinel.err.log" 2>/dev/null || true
    rm -f "$PID_FILE"
    exit 10
  fi

  if [[ -d ".supervisor" ]] || [[ -s "$RUN_DIR/sentinel.log" ]] || [[ -s "$RUN_DIR/sentinel.err.log" ]]; then
    echo "status=started_observed"
    exit 0
  fi

  sleep 1
done

echo "status=running_but_no_state_observed_yet"
echo "pid=$PID"
exit 0
