---
name: open
description: Open up to 4 task panes (one git worktree + branch per task, each running claude) in a new Windows Terminal grid for the current repo.
argument-hint: "<task> [task...] [.] [-Base <ref>] [-Command \"<cmd>\"]"
disable-model-invocation: true
allowed-tools: Bash(powershell.exe -NoProfile -ExecutionPolicy Bypass -File *)
---

Run this exact command once with the Bash tool, from the current project directory:

```
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_PLUGIN_ROOT}/src/task-grid.ps1" $ARGUMENTS
```

If no arguments were given, the script prints its usage; show that to the user instead of guessing task names.

Then report, in one or two lines: which panes opened (task name, branch, worktree folder) and any task the script skipped with its reason. Do not do anything else.

Windows only: it needs Windows Terminal (`wt.exe`). The script itself checks this and fails with a clear message.
