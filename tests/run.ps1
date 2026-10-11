# Minimal test runner for TaskGrid (Windows PowerShell 5.1, no external modules).
# Usage: powershell -NoProfile -ExecutionPolicy Bypass -File tests\run.ps1 [file-name-filter]
param([string]$Filter)

$root = Split-Path $PSScriptRoot -Parent
foreach ($f in 'Common', 'Layout', 'Worktree', 'GridMode', 'TeamConfig', 'TeamFiles', 'TeamMode') {
    $p = Join-Path $root "src\lib\$f.ps1"
    if (Test-Path $p) { . $p }
}

$script:Passes = 0
$script:Failures = 0

function Test([string]$Name, [scriptblock]$Body) {
    try { & $Body; $script:Passes++; Write-Host "  ok   $Name" -ForegroundColor Green }
    catch { $script:Failures++; Write-Host "  FAIL $Name" -ForegroundColor Red; Write-Host "       $($_.Exception.Message)" }
}

function Assert-Equal($Expected, $Actual, [string]$What = 'value') {
    $e = if ($Expected -is [array]) { @($Expected) -join '|' } else { "$Expected" }
    $a = if ($Actual -is [array]) { @($Actual) -join '|' } else { "$Actual" }
    if ($e -ne $a) { throw "${What}: expected <$e> but got <$a>" }
}

function Assert-True($Condition, [string]$Message) { if (-not $Condition) { throw $Message } }

function Assert-Match([string]$Text, [string]$Pattern) {
    if ($Text -notmatch $Pattern) { throw "expected text to match <$Pattern>" }
}

function Assert-Throws([scriptblock]$Body, [string]$Pattern) {
    $threw = $false
    try { & $Body } catch {
        $threw = $true
        if ($_.Exception.Message -notmatch $Pattern) { throw "threw <$($_.Exception.Message)>, expected <$Pattern>" }
    }
    if (-not $threw) { throw "expected an exception matching <$Pattern>" }
}

function New-TempRepo {
    $dir = Join-Path ([IO.Path]::GetTempPath()) ('tg-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
    New-Item -ItemType Directory $dir | Out-Null
    git -C $dir init -q -b main
    Set-Content (Join-Path $dir 'a.txt') 'x'
    git -C $dir add -A
    git -C $dir -c user.email=t@t -c user.name=t commit -q -m init
    return $dir
}

foreach ($t in Get-ChildItem $PSScriptRoot -Filter '*.Tests.ps1' | Sort-Object Name) {
    if ($Filter -and $t.Name -notmatch $Filter) { continue }
    Write-Host $t.Name
    . $t.FullName
}

Write-Host ''
Write-Host "$($script:Passes) passed, $($script:Failures) failed"
if ($script:Failures -gt 0) { exit 1 }
exit 0
