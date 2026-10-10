<#
.SYNOPSIS
  Open task sessions in one Windows Terminal window, split as a grid of any size.

.DESCRIPTION
  Works on the git repo of the current directory (or -Repo).
  Each task gets its own git worktree (sibling folder "<repo>-worktrees\<task>")
  on its own branch, so parallel Claude sessions never touch each other's files.
  "." means the main checkout.

  Task name -> branch:  "guard-ai" -> feat/guard-ai,  "fix/noise" -> fix/noise.
  Existing worktree or branch is reused; a new branch starts from -Base.

  Layout: an optional "RxC" argument (rows x columns, e.g. 2x3) fixes the grid;
  panes without a task name are filled with t1, t2, ...
  Without RxC the grid fits the task count (3 -> 2x2 with one empty slot, 6 -> 2x3).
  Panes fill in reading order: left to right, then top to bottom.

.EXAMPLE
  grid 2x3
.EXAMPLE
  grid 2x3 guard-ai fence-ui
.EXAMPLE
  grid guard-ai fence-ui fix/noise .
.EXAMPLE
  grid 3 -Command "claude --continue"
#>
[CmdletBinding(PositionalBinding = $false)]
param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$Tasks,
    [string]$Repo = (Get-Location).Path,
    [string]$Base = 'origin/main',
    [string]$Command = 'claude'
)

# --- Parse layout ("RxC" or a bare pane count) out of the task list ---
$rows = 0; $cols = 0; $count = 0
$names = @()
foreach ($t in $Tasks) {
    if ($t -match '^(\d+)[xX](\d+)$') { $rows = [int]$Matches[1]; $cols = [int]$Matches[2] }
    elseif ($t -match '^\d+$') { $count = [int]$t }
    else { $names += $t }
}

if ($rows -gt 0) {
    if ($rows * $cols -lt $names.Count) {
        Write-Error "Grid ${rows}x${cols} has $($rows * $cols) panes but $($names.Count) tasks were given."
        exit 1
    }
    $count = $rows * $cols
}
else {
    if ($count -lt $names.Count) { $count = $names.Count }
    if ($count -eq 0) {
        Get-Help $PSCommandPath -Detailed
        exit 1
    }
    $cols = [int][Math]::Ceiling([Math]::Sqrt($count))
    $rows = [int][Math]::Ceiling($count / $cols)
}

# Fill unnamed panes with t1, t2, ... (skipping names already used).
$n = 1
while ($names.Count -lt $count) {
    if ($names -notcontains "t$n") { $names += "t$n" }
    $n++
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

# --- Prepare one worktree per task ---
$panes = @()
foreach ($task in $names) {
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

# Recompute the grid if some tasks were skipped (keep the column count when it still fits).
$count = $panes.Count
if ($count -lt $cols) { $cols = $count }
$rows = [int][Math]::Ceiling($count / $cols)

# --- Build the wt.exe command line ---
# wt.exe splits subcommands on ';', so a literal ';' in the pane command must be "\;".
$paneCommand = $Command -replace ';', '\;'
$inv = [Globalization.CultureInfo]::InvariantCulture

function PaneArgs($pane) {
    return @('--title', $pane.Title, '--suppressApplicationTitle', '-d', $pane.Dir,
             'powershell', '-NoExit', '-Command', $paneCommand)
}

# Size of the new pane when splitting k equal panes off the current one: (k-1)/k.
function SplitSize($k) {
    return ([double]($k - 1) / $k).ToString('0.####', $inv)
}

# Panes must be independent Claude sessions: when this runs from inside Claude Code,
# its session variables (CLAUDECODE, CLAUDE_CODE_CHILD_SESSION, ...) would leak into
# every pane and turn off transcript saving there.
Get-ChildItem Env: | Where-Object { $_.Name -match '^(CLAUDECODE|CLAUDE_|CODEX_COMPANION_)' } |
    ForEach-Object { Remove-Item "Env:$($_.Name)" }

# Pane i sits at row [i / cols], column [i % cols] (reading order).
# Build order: the top pane of every column, then each column downwards.
# wt numbers panes 0,1,2... in creation order. Each split is a separate wt call into a
# named window that first focuses its target pane by id, with a pause in between:
# a freshly created pane grabs focus asynchronously, and inside one wt command line
# that late focus can redirect the next split to the wrong pane.
$window = 'grid-' + (Get-Date -Format 'HHmmssfff')
$paneId = @{}
$nextId = 0

& wt.exe @(@('-M', '-w', $window, 'new-tab') + (PaneArgs $panes[0]))
$paneId[0] = $nextId++
Start-Sleep -Milliseconds 1200

function AddPane($from, $to, $dir, $k) {
    & wt.exe @(@('-w', $window, 'focus-pane', '-t', $script:paneId[$from],
                 ';', 'split-pane', $dir, '-s', (SplitSize $k)) + (PaneArgs $panes[$to]))
    $script:paneId[$to] = $script:nextId++
    Start-Sleep -Milliseconds 500
}

for ($c = 1; $c -lt $cols; $c++) {
    AddPane ($c - 1) $c '-V' ($cols - $c + 1)
}
for ($c = 0; $c -lt $cols; $c++) {
    $colRows = @(0..($rows - 1) | Where-Object { $_ * $cols + $c -lt $count }).Count
    for ($r = 1; $r -lt $colRows; $r++) {
        AddPane (($r - 1) * $cols + $c) ($r * $cols + $c) '-H' ($colRows - $r + 1)
    }
}

Write-Host ""
Write-Host "Opened $count pane(s) as ${rows}x${cols}."
Write-Host "Clean up a merged task:  git worktree remove $worktreeRoot\<task>"
