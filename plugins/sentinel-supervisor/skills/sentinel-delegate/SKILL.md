---
name: sentinel-delegate
description: Use the locally installed Sentinel binary to run a supervised coder/supervisor pair for coding tasks while Codex monitors progress and reports updates.
---

Use this skill when the user wants Sentinel to perform a coding task through its supervisor/coder workflow.

Core contract:

- Sentinel does the coding work.
- Codex observes, monitors, explains, and summarizes.* Codex must not directly edit project code unless the user explicitly asks.
* Sentinel must be installed separately and available as `sentinel` in PATH.
* Adapter scripts must be resolved relative to this skill directory, not relative to the target project.

Path resolution rule:

* Let `SKILL_DIR` mean the installed directory that contains this `SKILL.md`.
* Do not run scripts through repo-relative paths such as `plugins/sentinel-supervisor/skills/sentinel-delegate/scripts/...`.
* In normal user projects, that repo-relative path will not exist.
* Instead, run scripts by absolute path under this installed skill directory:

  * `$SKILL_DIR/scripts/preflight_update.sh`
  * `$SKILL_DIR/scripts/start_sentinel.sh`
  * `$SKILL_DIR/scripts/check_sentinel.sh`
  * `$SKILL_DIR/scripts/finalize_sentinel.sh`

Before running anything, read:

* `$SKILL_DIR/references/COMMAND_ORDER.md`
* `$SKILL_DIR/references/SENTINEL_RUNTIME.md`

Workflow:

1. Parse the user request.

   Extract supported Sentinel parameters only:

   * task file, usually `TASK.md`;
   * `--model MODEL`, if provided;
   * `--coder-mod MODEL`, if provided;
   * `--super-mod MODEL`, if provided;
   * `--start-over`, if provided;
   * `--clean`, only if explicitly provided;
   * `--adversary`, if provided;
   * repeated `--protected-path PATH`, if provided.

   Do not invent parameter values.

   If the user provides `--coder-mod` without `--super-mod`, or `--super-mod` without `--coder-mod`, stop and ask for the missing paired parameter.

   Reject unknown Sentinel arguments instead of silently forwarding them.

2. Run Sentinel preflight and update.

   Run:

   `$SKILL_DIR/scripts/preflight_update.sh`

   If Sentinel is missing, tell the user how to install it and stop.

   If Sentinel reports that an update is available, run `sentinel update` through the preflight script before starting work.

   If `sentinel doctor` fails, stop and report the failure. Do not start Sentinel.

3. Start Sentinel in the background.

   Run:

   `$SKILL_DIR/scripts/start_sentinel.sh --task <task-file> [sentinel-options...]`

   Preserve all supported parameters from the user request.

   The command must be built in the order described in `COMMAND_ORDER.md`.

   After start, report to the user:

   * whether Sentinel started or failed to start;
   * task file;
   * exact parameters passed;
   * log path: `.codex/sentinel-run/`;
   * state path: `.supervisor/`.

4. Monitor Sentinel.

   While Sentinel is running, periodically run:

   `$SKILL_DIR/scripts/check_sentinel.sh`

   Use the latest checkpoint observation to report progress. Do not claim true continuous streaming.

   Primary monitoring sources:

   * `.supervisor/config.json`
   * `.supervisor/PROGRESS.md`
   * `.supervisor/DECISIONS.md`
   * `.supervisor/HANDOFF.md`
   * `.supervisor/events.jsonl`
   * `.supervisor/log.jsonl`
   * `.supervisor/supervisor_wakes.jsonl`
   * `.supervisor/FINAL_REPORT.md`, if present

   Secondary monitoring sources:

   * `.codex/sentinel-run/command.txt`
   * `.codex/sentinel-run/launch.json`
   * `.codex/sentinel-run/context.txt`
   * `.codex/sentinel-run/sentinel.log`
   * `.codex/sentinel-run/sentinel.err.log`
   * `git status --short`
   * `git diff --stat`

   Progress reports should include:

   * running/exited status;
   * current phase;
   * supervisor/coder decision;
   * files changed;
   * validation status;
   * blockers;
   * next expected step.

5. Detect launch failures.

   If Sentinel exits but `.supervisor/` was never created, treat this as a launch failure, not a normal empty run.

   Report:

   * command from `.codex/sentinel-run/command.txt`;
   * launch parameters from `.codex/sentinel-run/launch.json`;
   * stdout tail from `.codex/sentinel-run/sentinel.log`;
   * stderr tail from `.codex/sentinel-run/sentinel.err.log`;
   * whether `.supervisor/` exists.

6. Finalize after Sentinel exits.

   Run:

   `$SKILL_DIR/scripts/finalize_sentinel.sh`

   The final report must be based primarily on:

   * `.supervisor/FINAL_REPORT.md`
   * `git diff --stat`
   * `git diff --name-only`
   * `git status --short`

7. Final response.

   Summarize:

   * final outcome;
   * changed files;
   * validation;
   * risks;
   * unresolved blockers;
   * recommended next action.

Important safety notes:

* Do not use `--clean` unless the user explicitly requested it.
* Do not mutate `.supervisor/` manually.
* Do not edit project code yourself unless the user explicitly asks.
* Do not run `codex login` automatically. If auth is missing, tell the user to log in manually.
* Do not start a new Sentinel run if an existing valid Sentinel process is already running for the current workspace.
* If startup logs are empty, `.supervisor/` is missing, and the Sentinel PID has exited, report a launch failure instead of continuing.
