<#
.SYNOPSIS
  Open up to 4 task sessions in one Windows Terminal window, split as a grid.

.DESCRIPTION
  Works on the git repo of the current directory (or -Repo).
  Each task gets its own git worktree (sibling folder "<repo>-worktrees\<task>")
  on its own branch, so parallel Claude sessions never touch each other's files.
  "." means the main checkout.

  Task name -> branch:  "guard-ai" -> feat/guard-ai,  "fix/noise" -> fix/noise.
  Existing worktree or branch is reused; a new branch starts from -Base.

  Layout:  1 = full,  2 = left|right,  3 = 2 top + 1 bottom-left,  4 = 2x2.

.EXAMPLE
  task-grid guard-ai fence-ui fix/noise .
.EXAMPLE
  task-grid guard-ai -Command "claude --continue"
.EXAMPLE
  task-grid guard-ai fence-ui -Repo E:\Unity-WorkSpace\TileThieves
#>
[CmdletBinding(PositionalBinding = $false)]
param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$Tasks,
    [string]$Repo = (Get-Location).Path,
    [string]$Base = 'origin/main',
    [string]$Command = 'claude'
)

if (-not $Tasks -or $Tasks.Count -eq 0) {
    Get-Help $PSCommandPath -Detailed
    exit 1
}
if ($Tasks.Count -gt 4) {
    Write-Error "At most 4 tasks per window (got $($Tasks.Count))."
    exit 1
}
if (-not (Get-Command wt.exe -ErrorAction SilentlyContinue)) {
    Write-Error 'Windows Terminal (wt.exe) not found.'
    exit 1
}

$top = git -C $Repo rev-parse --show-toplevel
if ($LASTEXITCODE -ne 0) {
    Write-Error "Not inside a git repo: $Repo"
    exit 1
}
# Inside a worktree, show-toplevel is the worktree itself; use the main checkout instead.
$commonDir = git -C $Repo rev-parse --path-format=absolute --git-common-dir
$repoRoot = (Split-Path $commonDir -Parent) -replace '/', '\'
if (-not (Test-Path (Join-Path $repoRoot '.git'))) { $repoRoot = $top -replace '/', '\' }

$worktreeRoot = Join-Path (Split-Path $repoRoot -Parent) ((Split-Path $repoRoot -Leaf) + '-worktrees')

if ($Base -like 'origin/*') {
    Write-Host "Fetching origin..."
    git -C $repoRoot fetch origin --quiet
}

$panes = @()
foreach ($task in $Tasks) {
    if ($task -eq '.') {
        $panes += @{ Dir = $repoRoot; Title = 'main-checkout' }
        continue
    }

    $branch = if ($task -match '/') { $task } else { "feat/$task" }
    $dir = Join-Path $worktreeRoot ($task -replace '/', '-')

    if (Test-Path $dir) {
        Write-Host "[$task] reuse worktree $dir"
    }
    else {
        git -C $repoRoot show-ref --verify --quiet "refs/heads/$branch"
        if ($LASTEXITCODE -eq 0) {
            Write-Host "[$task] new worktree on existing branch $branch"
            git -C $repoRoot worktree add $dir $branch
        }
        else {
            Write-Host "[$task] new worktree, new branch $branch from $Base"
            # --no-track: the task branch must not pull/push against main.
            git -C $repoRoot worktree add --no-track -b $branch $dir $Base
        }
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "[$task] worktree add failed (branch checked out elsewhere?). Skipped."
            continue
        }
    }
    $panes += @{ Dir = $dir; Title = $task }
}

if ($panes.Count -eq 0) { exit 1 }

# wt.exe splits subcommands on ';', so a literal ';' in the pane command must be "\;".
$paneCommand = $Command -replace ';', '\;'

function PaneArgs($pane) {
    return @('--title', $pane.Title, '--suppressApplicationTitle', '-d', $pane.Dir,
             'powershell', '-NoExit', '-Command', $paneCommand)
}

# Fill order: top-left, top-right, bottom-left, bottom-right.
$wtArgs = @('-w', 'new', 'new-tab') + (PaneArgs $panes[0])
if ($panes.Count -ge 2) { $wtArgs += @(';', 'split-pane', '-V') + (PaneArgs $panes[1]) }
if ($panes.Count -ge 3) { $wtArgs += @(';', 'move-focus', 'left', ';', 'split-pane', '-H') + (PaneArgs $panes[2]) }
if ($panes.Count -ge 4) { $wtArgs += @(';', 'move-focus', 'right', ';', 'split-pane', '-H') + (PaneArgs $panes[3]) }

& wt.exe @wtArgs

Write-Host ""
Write-Host "Clean up a merged task:  git worktree remove $worktreeRoot\<task>"
