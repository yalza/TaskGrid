# Ensures $Dir is a worktree of $RepoRoot on $Branch, creating the branch from $Base when missing.
function Initialize-Worktree([string]$RepoRoot, [string]$Dir, [string]$Branch, [string]$Base, [string]$Label) {
    if (Test-Path $Dir) {
        Write-Host "[$Label] reuse worktree $Dir"
        return $true
    }
    git -C $RepoRoot show-ref --verify --quiet "refs/heads/$Branch"
    if ($LASTEXITCODE -eq 0) {
        Write-Host "[$Label] new worktree on existing branch $Branch"
        git -C $RepoRoot worktree add $Dir $Branch | Out-Host
    }
    else {
        Write-Host "[$Label] new worktree, new branch $Branch from $Base"
        # --no-track: the branch must not pull/push against main.
        git -C $RepoRoot worktree add --no-track -b $Branch $Dir $Base | Out-Host
    }
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "[$Label] worktree add failed (branch checked out elsewhere?). Skipped."
        return $false
    }
    return $true
}
