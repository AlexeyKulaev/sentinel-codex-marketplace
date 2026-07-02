# Sentinel Supervisor for Codex

## Installation

Install Sentinel:

```bash 
pipx install git+https://github.com/Makson179/Sentinel.git
sentinel doctor
```

## Add Codex Marketplace

```bash
codex plugin marketplace add AlexeyKulaev/sentinel-codex-marketplace --ref main
```

## Install Plugin

```bash
codex plugin add sentinel-supervisor@sentinel-marketplace
```

Alternatively, open Codex:
  
```bash
codex
/plugins
```

Then install **Sentinel Supervisor** from the plugin list.

## Usage

In a project directory, create a task file:

```bash
cat > TASK.md <<'EOF'
Create hello.py that prints "hello from sentinel".
Run python3 hello.py to validate it.
EOF
```

Then run Sentinel Supervisor in Codex:

```text
@Sentinel Supervisor run TASK.md with --coder-mod gpt-5.5 --super-mod gpt-5.5 --start-over and keep me updated
```

## How the Plugin Works

The plugin:

* checks whether the Codex plugin marketplace is behind `main`;
* automatically refreshes, removes, and reinstalls the plugin when a newer commit exists;
* checks `sentinel doctor`;
* checks `sentinel --version`;
* runs `sentinel update` when an update is available;
* starts `sentinel --task TASK.md ...`;
* monitors `.supervisor/` state files;
* reports progress in Codex;
* summarizes `.supervisor/FINAL_REPORT.md` and `git diff`.

Sentinel itself controls Codex through:

```bash
codex app-server --listen stdio://
```

using JSON-RPC.

The plugin only observes and reports progress.

## Update

Update the Sentinel binary:

```bash
sentinel update
sentinel doctor
```

The plugin checks for its own updates at the start of each skill run. It
compares the configured `sentinel-marketplace` snapshot commit with the latest
commit on `refs/heads/main`. If the Git remote is unreachable, the plugin logs
that the check was skipped and continues with the installed version. If the
commit hashes differ, it runs:

```bash
codex plugin marketplace upgrade sentinel-marketplace
codex plugin remove sentinel-supervisor@sentinel-marketplace
codex plugin add sentinel-supervisor@sentinel-marketplace
```

After an automatic plugin update, start a new Codex thread or rerun the request
so Codex loads the updated skill bundle.

Manual fallback:

```bash
codex plugin marketplace upgrade sentinel-marketplace
codex plugin remove sentinel-supervisor@sentinel-marketplace
codex plugin add sentinel-supervisor@sentinel-marketplace
```

If you only need to retry the install step:

```bash
codex plugin remove sentinel-supervisor@sentinel-marketplace
codex plugin add sentinel-supervisor@sentinel-marketplace
```

For every published plugin release, bump
`plugins/sentinel-supervisor/.codex-plugin/plugin.json` `version`; Codex caches
installed plugin bundles by plugin identity and version.
