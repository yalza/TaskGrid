Test 'session marker variables are recognised' {
    foreach ($n in 'CLAUDECODE', 'CLAUDE_CODE_CHILD_SESSION', 'CLAUDE_CODE_MESSAGING_SOCKET', 'CLAUDE_PLUGIN_DATA', 'CODEX_COMPANION_SESSION_ID', 'CLAUDE_EFFORT', 'CLAUDE_PID') {
        Assert-True (Test-SessionEnvName $n) "$n should be a session variable"
    }
}

Test 'user configuration variables are kept' {
    foreach ($n in 'CLAUDE_CODE_EFFORT_LEVEL', 'CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS', 'ANTHROPIC_API_KEY', 'PATH', 'CLAUDE_CONFIG_DIR') {
        Assert-True (-not (Test-SessionEnvName $n)) "$n should be kept"
    }
}

Test 'Clear-SessionEnv removes markers only' {
    $env:CLAUDECODE = '1'; $env:CLAUDE_CODE_EFFORT_LEVEL = 'low'
    try {
        Clear-SessionEnv
        Assert-True ($null -eq $env:CLAUDECODE) 'CLAUDECODE should be removed'
        Assert-Equal 'low' $env:CLAUDE_CODE_EFFORT_LEVEL 'CLAUDE_CODE_EFFORT_LEVEL'
    } finally { Remove-Item Env:CLAUDE_CODE_EFFORT_LEVEL -ErrorAction SilentlyContinue }
}

Test 'ConvertTo-PsLiteral doubles single quotes' {
    Assert-Equal "'Bob''s Game'" (ConvertTo-PsLiteral "Bob's Game")
}

Test 'Get-WorktreeRoot is a sibling folder' {
    Assert-Equal 'E:\Work\Game-worktrees' (Get-WorktreeRoot 'E:\Work\Game')
}

Test 'Resolve-RepoRoot from a worktree returns the main checkout' {
    $repo = New-TempRepo
    $wt = "$repo-wt"
    git -C $repo worktree add -q -b side $wt 2>$null
    Assert-Equal $repo (Resolve-RepoRoot $wt) 'repo root'
    Assert-Equal $repo (Resolve-RepoRoot $repo) 'repo root from main'
}

Test 'Resolve-CheckoutTop returns the worktree itself' {
    $repo = New-TempRepo
    $wt = "$repo-wt2"
    git -C $repo worktree add -q -b side2 $wt 2>$null
    Assert-Equal $wt (Resolve-CheckoutTop $wt) 'checkout top'
}

Test 'Resolve-RepoRoot outside git throws' {
    Assert-Throws { Resolve-RepoRoot ([IO.Path]::GetTempPath()) } 'Not inside a git repo'
}

Test 'Write-Utf8File writes no BOM and LF only' {
    $p = Join-Path ([IO.Path]::GetTempPath()) ('tg-' + [guid]::NewGuid().ToString('N') + '.txt')
    Write-Utf8File $p "a`r`nb"
    $bytes = [IO.File]::ReadAllBytes($p)
    Assert-Equal 97 $bytes[0] 'first byte'
    Assert-Equal 3 $bytes.Length 'length'
}

Test 'Get-TextHash is stable lowercase hex' {
    Assert-Equal (Get-TextHash 'abc') (Get-TextHash 'abc') 'same input'
    Assert-Match (Get-TextHash 'abc') '^[0-9a-f]{64}$'
}
