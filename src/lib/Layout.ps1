# Grid geometry and Windows Terminal calls shared by grid mode and team mode.

function Get-GridShape([int]$Count, [int]$Rows = 0, [int]$Cols = 0) {
    if ($Rows -gt 0 -and $Cols -gt 0) { return @{ Rows = $Rows; Cols = $Cols } }
    $c = [int][Math]::Ceiling([Math]::Sqrt($Count))
    return @{ Rows = [int][Math]::Ceiling($Count / $c); Cols = $c }
}

# Size of the new pane when splitting k equal panes off the current one: (k-1)/k.
# Invariant culture: wt rejects "0,5".
function Format-SplitSize([int]$K) {
    return ([double]($K - 1) / $K).ToString('0.####', [Globalization.CultureInfo]::InvariantCulture)
}

# Splits that build $Count panes in $Cols columns, panes numbered in reading order.
# First the top pane of every column, then each column downwards.
function Get-SplitPlan([int]$Count, [int]$Cols) {
    if ($Count -lt $Cols) { $Cols = $Count }
    $rows = [int][Math]::Ceiling($Count / $Cols)
    $plan = @()
    for ($c = 1; $c -lt $Cols; $c++) {
        $plan += @{ From = $c - 1; To = $c; Dir = '-V'; K = $Cols - $c + 1 }
    }
    for ($c = 0; $c -lt $Cols; $c++) {
        $colRows = @(0..($rows - 1) | Where-Object { $_ * $Cols + $c -lt $Count }).Count
        for ($r = 1; $r -lt $colRows; $r++) {
            $plan += @{ From = ($r - 1) * $Cols + $c; To = $r * $Cols + $c; Dir = '-H'; K = $colRows - $r + 1 }
        }
    }
    return , $plan
}

# Opens a maximized window named $Window. $PaneArgs[i] is the string[] of wt pane arguments
# for pane i. wt numbers panes 0,1,2... in creation order. Each split is a separate wt call
# that first focuses its target pane by id, with a pause in between: a new pane grabs focus
# late, which would send the next split of a single combined command line to the wrong pane.
function Open-WtGrid([string]$Window, [object[]]$PaneArgs, [object[]]$Plan) {
    & wt.exe @(@('-M', '-w', $Window, 'new-tab') + $PaneArgs[0])
    Start-Sleep -Milliseconds 1200
    $ids = @{ 0 = 0 }
    $next = 1
    foreach ($s in $Plan) {
        & wt.exe @(@('-w', $Window, 'focus-pane', '-t', $ids[$s.From], ';',
                     'split-pane', $s.Dir, '-s', (Format-SplitSize $s.K)) + $PaneArgs[$s.To])
        $ids[$s.To] = $next++
        Start-Sleep -Milliseconds 500
    }
}
