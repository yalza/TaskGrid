# Plain grid mode: "grid 2x3", "grid 4", "grid guard-ai fence-ui .".

function Get-GridArgs([string[]]$Tasks) {
    $rows = 0; $cols = 0; $count = 0
    $names = @()
    foreach ($t in @($Tasks)) {
        if ($t -match '^(\d+)[xX](\d+)$') { $rows = [int]$Matches[1]; $cols = [int]$Matches[2] }
        elseif ($t -match '^\d+$') { $count = [int]$t }
        elseif ($t) { $names += $t }
    }
    if ($rows -gt 0) {
        if ($rows * $cols -lt $names.Count) {
            throw "Grid ${rows}x${cols} has $($rows * $cols) panes but $($names.Count) tasks were given."
        }
        $count = $rows * $cols
    }
    elseif ($count -lt $names.Count) { $count = $names.Count }

    # Fill unnamed panes with t1, t2, ... (skipping names already used).
    $n = 1
    while ($names.Count -lt $count) {
        if ($names -notcontains "t$n") { $names += "t$n" }
        $n++
    }
    return @{ Names = $names; Rows = $rows; Cols = $cols; Count = $count }
}

function Invoke-GridMode([string[]]$Tasks, [string]$Repo, [string]$Base, [string]$Command, [string]$HelpPath) {
    $a = Get-GridArgs $Tasks
    if ($a.Count -eq 0) {
        Get-Help $HelpPath -Detailed | Out-Host
        return 1
    }
    $shape = Get-GridShape $a.Count $a.Rows $a.Cols
    $repoRoot = Resolve-RepoRoot $Repo
    $worktreeRoot = Get-WorktreeRoot $repoRoot

    if ($Base -like 'origin/*') {
        Write-Host 'Fetching origin...'
        git -C $repoRoot fetch origin --quiet
    }

    $panes = @()
    foreach ($task in $a.Names) {
        if ($task -eq '.') { $panes += @{ Dir = $repoRoot; Title = 'main-checkout' }; continue }
        $branch = if ($task -match '/') { $task } else { "feat/$task" }
        $dir = Join-Path $worktreeRoot ($task -replace '/', '-')
        if (Initialize-Worktree $repoRoot $dir $branch $Base $task) { $panes += @{ Dir = $dir; Title = $task } }
    }
    if ($panes.Count -eq 0) { return 1 }

    # Keep the column count when it still fits after skipped tasks.
    $cols = $shape.Cols
    if ($panes.Count -lt $cols) { $cols = $panes.Count }
    $rows = [int][Math]::Ceiling($panes.Count / $cols)

    # wt.exe splits subcommands on ';', so a literal ';' in the pane command must be "\;".
    $paneCommand = $Command -replace ';', '\;'
    $paneArgs = @()
    foreach ($p in $panes) {
        $paneArgs += , @('--title', $p.Title, '--suppressApplicationTitle', '-d', $p.Dir,
                         'powershell', '-NoExit', '-Command', $paneCommand)
    }

    Clear-SessionEnv
    Open-WtGrid ('grid-' + (Get-Date -Format 'HHmmssfff')) $paneArgs (Get-SplitPlan $panes.Count $cols)

    Write-Host ''
    Write-Host "Opened $($panes.Count) pane(s) as ${rows}x${cols}."
    Write-Host "Clean up a merged task:  git worktree remove $worktreeRoot\<task>"
    return 0
}
