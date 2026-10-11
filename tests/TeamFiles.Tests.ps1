$tplPath = Join-Path (Split-Path $PSScriptRoot -Parent) 'templates\protocol.md'

function New-TestContext([string]$RepoRoot = 'E:\Work\Game') {
    $cfg = '{ "team": "tt", "permissionMode": "auto", "unityTools": ["mcp__UnityMCP", "Skill(skill:unity-skills)"], "members": [ { "name": "pm", "agent": "pm", "model": "sonnet", "effort": "medium", "advisor": "opus" }, { "name": "integrator", "agent": "integrator", "model": "sonnet", "workspace": "main", "unity": true }, { "name": "reviewer", "agent": "reviewer", "model": "sonnet", "effort": "high", "readonly": true } ] }' | ConvertFrom-Json
    return Get-TeamContext $cfg $RepoRoot
}

Test 'context paths and session names' {
    $c = New-TestContext
    Assert-Equal 'E:\Work\Game-worktrees\_team' $c.TeamDir
    Assert-Equal 'tt-pm' $c.Members[0].SessionName
    Assert-Equal 'E:\Work\Game-worktrees\tt-pm' $c.Members[0].Workspace
    Assert-Equal 'team/tt-pm' $c.Members[0].Branch
    Assert-Equal 'E:\Work\Game' $c.Members[1].Workspace
    Assert-True $c.Members[1].IsMain 'integrator sits in main'
}

Test 'rule paths are POSIX with a lowercase drive' {
    Assert-Equal '//e/Work/Game-worktrees/_team' (ConvertTo-RulePath 'E:\Work\Game-worktrees\_team\')
}

Test 'settings allow reading and editing the team folder for everyone' {
    $c = New-TestContext
    $s = New-MemberSettings $c $c.Members[0]
    Assert-Equal @('Read(//e/Work/Game-worktrees/_team/**)', 'Edit(//e/Work/Game-worktrees/_team/**)') $s.permissions.allow
}

Test 'settings deny Unity tools to non-owners only' {
    $c = New-TestContext
    Assert-Equal @('mcp__UnityMCP', 'Skill(skill:unity-skills)') (New-MemberSettings $c $c.Members[0]).permissions.deny
    Assert-Equal 0 @((New-MemberSettings $c $c.Members[1]).permissions.deny).Count
}

Test 'readonly members cannot edit their workspace' {
    $c = New-TestContext
    $deny = @((New-MemberSettings $c $c.Members[2]).permissions.deny)
    Assert-True ($deny -contains 'Edit(//e/Work/Game-worktrees/tt-reviewer/**)') 'Edit denied'
    Assert-True (@($deny | Where-Object { $_ -like 'Write(*' }).Count -eq 0) 'no Write rules (they are not matched)'
}

Test 'protocol is deterministic and complete' {
    $c = New-TestContext
    $a = New-ProtocolText $c 'Rule A' $tplPath
    $b = New-ProtocolText $c 'Rule A' $tplPath
    Assert-Equal (Get-TextHash $a) (Get-TextHash $b) 'hash'
    Assert-True ($a -notmatch '\{\{') 'no unreplaced tokens'
    Assert-Match $a '\| `tt-pm` \| pm \| sonnet, effort medium, advisor opus \|'
    Assert-Match $a 'Unity Editor owner: `tt-integrator`'
    Assert-Match $a 'Rule A'
    Assert-Match $a 'select:SendMessage,ListAgents'
}

Test 'protocol without project rules says so' {
    $c = New-TestContext
    Assert-Match (New-ProtocolText $c '' $tplPath) 'No project-specific rules'
}

Test 'launch script for a new session' {
    $c = New-TestContext
    $s = New-LaunchScript $c $c.Members[0] '11111111-2222-3333-4444-555555555555' $false
    Assert-Match $s "'--agent', 'pm', '--model', 'sonnet', '--effort', 'medium', '--advisor', 'opus', '--name', 'tt-pm', '--session-id', '11111111-2222-3333-4444-555555555555'"
    Assert-Match $s "'--permission-mode', 'auto'"
    Assert-Match $s "'--add-dir', 'E:\\Work\\Game-worktrees\\_team'"
    Assert-Match $s "'--settings', 'E:\\Work\\Game-worktrees\\_team\\settings\\pm.json'"
    Assert-Match $s "'--append-system-prompt-file', 'E:\\Work\\Game-worktrees\\_team\\protocol.md'"
    Assert-Match $s "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS = '0'"
    Assert-Match $s 'Remove-Item'
}

Test 'launch script for resume omits session-id and optional flags when unset' {
    $c = New-TestContext
    $s = New-LaunchScript $c $c.Members[1] 'abc' $true
    Assert-Match $s "'--resume', 'abc'"
    Assert-True ($s -notmatch '--session-id') 'no --session-id'
    Assert-True ($s -notmatch '--effort') 'no --effort'
    Assert-True ($s -notmatch '--advisor') 'no --advisor'
}

Test 'launch script parses with spaces and apostrophes in the path' {
    $c = New-TestContext "C:\My Games\Bob's Game"
    $s = New-LaunchScript $c $c.Members[0] 'id' $false
    $errs = $null
    [void][Management.Automation.PSParser]::Tokenize($s, [ref]$errs)
    Assert-Equal 0 @($errs).Count 'parse errors'
    Assert-True ($s.Contains("Set-Location -LiteralPath 'C:\My Games\Bob''s Game-worktrees\tt-pm'")) 'literal workspace path'
}

Test 'sessions round trip' {
    $p = Join-Path ([IO.Path]::GetTempPath()) ('tg-' + [guid]::NewGuid().ToString('N') + '.json')
    Write-Sessions $p @{ pm = @{ Id = 'a'; ProtocolHash = 'h1' } }
    $m = Read-Sessions $p
    Assert-Equal 'a' $m['pm'].Id
    Assert-Equal 'h1' $m['pm'].ProtocolHash
    Assert-Equal 0 (Read-Sessions 'C:\nope.json').Count
}

Test 'resume plan reuses ids and warns' {
    $sessions = @{ pm = @{ Id = 'a'; ProtocolHash = 'old' } }
    $plan = Get-ResumePlan $sessions @('pm', 'dev') 'new' $true
    Assert-Equal 'a' $plan.Entries['pm'].Id
    Assert-True $plan.Entries['pm'].Resume 'pm resumes'
    Assert-True (-not $plan.Entries['dev'].Resume) 'dev starts fresh'
    Assert-Match ($plan.Warnings -join ';') 'pm: the protocol changed'
    Assert-Match ($plan.Warnings -join ';') 'dev: no saved session'
}

Test 'fresh launch makes new ids without warnings' {
    $plan = Get-ResumePlan @{ pm = @{ Id = 'a'; ProtocolHash = 'h' } } @('pm') 'h' $false
    Assert-True ($plan.Entries['pm'].Id -ne 'a') 'new id'
    Assert-Equal 0 @($plan.Warnings).Count
}
