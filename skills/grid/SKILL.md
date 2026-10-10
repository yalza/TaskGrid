---
name: grid
description: Open parallel task panes (one git worktree + branch per task, each running claude) in a new Windows Terminal grid of any size, e.g. 2x3, for the current repo.
argument-hint: "[RxC | N] [task...] [.] [-Base <ref>] [-Command \"<cmd>\"]"
disable-model-invocation: true
allowed-tools: Bash(powershell.exe -NoProfile -ExecutionPolicy Bypass -File *)
---

Run this exact command once with the Bash tool, from the current project directory:

```
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_PLUGIN_ROOT}/src/grid.ps1" $ARGUMENTS
```

If no arguments were given, the script prints its usage; show that to the user instead of guessing task names.

Then report, in one or two lines: the grid size, which panes opened (task name, branch, worktree folder) and any task the script skipped with its reason. Do not do anything else.

Windows only: it needs Windows Terminal (`wt.exe`). The script itself checks this and fails with a clear message.
