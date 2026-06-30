# Sentinel Command Order

When constructing Sentinel commands, preserve this order:

1. Main command:

   `sentinel`

2. Subcommands:

   `doctor`
   `update`

3. Version/help flags:

   `--version`
   `-V`
   `--help`
   `-h`

4. Run options:

   `--task TASK.md`
   `--model MODEL`
   `--coder-mod MODEL`
   `--super-mod MODEL`
   `--start-over`
   `--clean`
   `--adversary`
   `--protected-path PATH`

Rules:

- Preserve user-provided parameters.
- Do not invent model names.
- `--coder-mod` must be used together with `--super-mod`.
- `--super-mod` must be used together with `--coder-mod`.
- `--clean` must be used only when the user explicitly requests it.
- `--protected-path PATH` may be repeated.
- Unknown arguments must be rejected instead of silently forwarded.
