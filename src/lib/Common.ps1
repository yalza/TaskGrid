# Shared helpers for grid mode and team mode.

# Variables that mark the Claude Code session this script runs in. A pane must not inherit
# them, or its claude thinks it is a child session (transcripts off, wrong session id).
$script:SessionEnvPattern = '^(CLAUDECODE|CLAUDE_CODE_CHILD_SESSION|CLAUDE_CODE_SESSION_ID|CLAUDE_CODE_SESSION_ATTENDED|CLAUDE_CODE_ENTRYPOINT|CLAUDE_CODE_EXECPATH|CLAUDE_CODE_BRIDGE_SESSION_ID|CLAUDE_CODE_MESSAGING_.*|CLAUDE_PID|CLAUDE_EFFORT|CLAUDE_PLUGIN_.*|CODEX_COMPANION_.*)$'

function Test-SessionEnvName([string]$Name) {
    return $Name -match $script:SessionEnvPattern
}

function Clear-SessionEnv {
    Get-ChildItem Env: | Where-Object { Test-SessionEnvName $_.Name } |
        ForEach-Object { Remove-Item ('Env:' + $_.Name) }
}

# Main checkout of the repo containing $Path, even when $Path is inside a linked worktree.
function Resolve-RepoRoot([string]$Path) {
    $top = git -C $Path rev-parse --show-toplevel 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $top) { throw "Not inside a git repo: $Path" }
    $commonDir = git -C $Path rev-parse --path-format=absolute --git-common-dir
    $root = (Split-Path $commonDir -Parent) -replace '/', '\'
    if (-not (Test-Path (Join-Path $root '.git'))) { $root = $top -replace '/', '\' }
    return $root
}

function Get-WorktreeRoot([string]$RepoRoot) {
    return Join-Path (Split-Path $RepoRoot -Parent) ((Split-Path $RepoRoot -Leaf) + '-worktrees')
}

# Top of the checkout $Path is in (the main checkout or a linked worktree).
function Resolve-CheckoutTop([string]$Path) {
    $top = git -C $Path rev-parse --show-toplevel 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $top) { throw "Not inside a git repo: $Path" }
    return ($top -replace '/', '\')
}

function ConvertTo-PsLiteral([string]$Text) {
    return "'" + ($Text -replace "'", "''") + "'"
}

# UTF-8 without BOM, LF line endings, so other tools and prompt caching see stable bytes.
function Write-Utf8File([string]$Path, [string]$Text) {
    $dir = Split-Path $Path -Parent
    if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Force $dir | Out-Null }
    [IO.File]::WriteAllText($Path, ($Text -replace "`r`n", "`n"), (New-Object Text.UTF8Encoding $false))
}

function Get-TextHash([string]$Text) {
    $sha = [Security.Cryptography.SHA256]::Create()
    $bytes = $sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($Text))
    return -join ($bytes | ForEach-Object { $_.ToString('x2') })
}
