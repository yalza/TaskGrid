---
name: grid
description: Open parallel task panes (one git worktree + branch per task, each running claude) in a Windows Terminal grid of any size, or open a whole role-based team from .claude/team.json ("team").
argument-hint: "[RxC | N] [task...] [.] | team [init -Preset <name> | member...] [-Resume] [-DryRun] [-Force]"
disable-model-invocation: true
allowed-tools: Bash(powershell.exe -NoProfile -ExecutionPolicy Bypass -File *)
---

Run this exact command once with the Bash tool, from the current project directory:

```
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_PLUGIN_ROOT}/src/grid.ps1" $ARGUMENTS
```

If no arguments were given, the script prints its usage; show that to the user instead of guessing task names.

For "team" runs, also report the team folder path and any warning the script printed (dirty main checkout, protocol changed, no saved session).

Then report, in one or two lines: the grid size, which panes opened (task name, branch, worktree folder) and any task the script skipped with its reason. Do not do anything else.

Windows only: it needs Windows Terminal (`wt.exe`). The script itself checks this and fails with a clear message.
