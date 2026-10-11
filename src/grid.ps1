<#
.SYNOPSIS
  Open task sessions in one Windows Terminal window, split as a grid of any size,
  or open a whole team of role-based Claude sessions ("grid team").

.DESCRIPTION
  Grid mode works on the git repo of the current directory (or -Repo).
  Each task gets its own git worktree (sibling folder "<repo>-worktrees\<task>")
  on its own branch. "." means the main checkout.
  Task name -> branch:  "guard-ai" -> feat/guard-ai,  "fix/noise" -> fix/noise.
  An optional "RxC" argument (rows x columns) fixes the grid; unnamed panes get t1, t2, ...

  Team mode reads .claude/team.json and opens one pane per member, each running
  claude with its own role, model and effort. See README.md.

.EXAMPLE
  grid 2x3
.EXAMPLE
  grid 2x3 guard-ai fence-ui
.EXAMPLE
  grid guard-ai fence-ui fix/noise .
.EXAMPLE
  grid team init -Preset unity-game
.EXAMPLE
  grid team
.EXAMPLE
  grid team pm gameplay reviewer -Resume
#>
[CmdletBinding(PositionalBinding = $false)]
param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$Tasks,
    [string]$Repo = (Get-Location).Path,
    [string]$Base = 'origin/main',
    [string]$Command = 'claude',
    [string]$Preset = 'basic',
    [switch]$Resume,
    [switch]$DryRun,
    [switch]$Force
)

$lib = Join-Path $PSScriptRoot 'lib'
foreach ($f in 'Common', 'Layout', 'Worktree', 'GridMode', 'TeamConfig', 'TeamFiles', 'TeamMode') {
    $p = Join-Path $lib "$f.ps1"
    if (Test-Path $p) { . $p }
}

if (-not $DryRun -and -not (Get-Command wt.exe -ErrorAction SilentlyContinue)) {
    Write-Error 'Windows Terminal (wt.exe) not found.'
    exit 1
}

try {
    if ($Tasks -and $Tasks[0] -eq 'team') {
        $rest = @($Tasks | Select-Object -Skip 1)
        $code = Invoke-TeamMode -Rest $rest -Repo $Repo -Base $Base -Preset $Preset -Resume:$Resume -DryRun:$DryRun -Force:$Force
    }
    else {
        $code = Invoke-GridMode -Tasks $Tasks -Repo $Repo -Base $Base -Command $Command -HelpPath $PSCommandPath
    }
}
catch {
    Write-Error $_.Exception.Message
    exit 1
}
exit ([int](@($code)[-1]))
