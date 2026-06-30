# Sentinel Codex Marketplace

This repository provides the Sentinel Supervisor plugin for Codex.

Sentinel itself is installed separately as a local `sentinel` command. This plugin only connects Codex to the installed Sentinel runtime.

## Install Sentinel

```bash
pipx install git+https://github.com/Makson179/Sentinel.git
sentinel doctor```

Add Codex marketplace
codex plugin marketplace add AlexeyKulaev/sentinel-codex-marketplace --ref main

Install plugin
codex plugin add sentinel-supervisor@sentinel-marketplace

Or open Codex:

codex
/plugins

Then install Sentinel Supervisor.

Use

In a project directory:

cat > TASK.md <<'EOF'
Create hello.py that prints "hello from sentinel".
Run python3 hello.py to validate it.
EOF

Then in Codex:

@Sentinel Supervisor run TASK.md with --coder-mod gpt-5.5 --super-mod gpt-5.5 --start-over and keep me updated
How the plugin works

The plugin:

checks sentinel doctor;
checks sentinel --version;
runs sentinel update when an update is available;
starts sentinel --task TASK.md ...;
monitors .supervisor/ state files;
reports progress in Codex;
summarizes .supervisor/FINAL_REPORT.md and git diff.

Sentinel itself controls Codex through codex app-server --listen stdio:// and JSON-RPC. The plugin only observes and reports.

Update

Update Sentinel binary:

sentinel update
sentinel doctor

Update Codex marketplace/plugin:

codex plugin marketplace upgrade sentinel-marketplace
codex plugin remove sentinel-supervisor@sentinel-marketplace
codex plugin add sentinel-supervisor@sentinel-marketplace


