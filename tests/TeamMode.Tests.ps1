# Tests must not depend on which claude sessions happen to run on this machine.
function Get-RunningSessionNames { return , @() }

function Get-TeamFixture([string]$Preset = 'basic') {
    $repo = New-TempRepo
    [void](Invoke-TeamInit $repo $Preset)
    git -C $repo add -A
    git -C $repo -c user.email=t@t -c user.name=t commit -q -m team
    return $repo
}

Test 'init creates team.json and the agents the preset uses' {
    $repo = New-TempRepo
    [void](Invoke-TeamInit $repo 'basic')
    foreach ($f in '.claude\team.json', '.claude\agents\pm.md', '.claude\agents\dev.md', '.claude\agents\reviewer.md') {
        Assert-True (Test-Path (Join-Path $repo $f)) "$f should exist"
    }
}

Test 'init keeps existing files' {
    $repo = New-TempRepo
    New-Item -ItemType Directory (Join-Path $repo '.claude\agents') | Out-Null
    Set-Content (Join-Path $repo '.claude\agents\pm.md') 'mine'
    [void](Invoke-TeamInit $repo 'basic')
    Assert-Equal 'mine' (Get-Content (Join-Path $repo '.claude\agents\pm.md'))
}

Test 'init with an unknown preset throws' {
    Assert-Throws { Invoke-TeamInit (New-TempRepo) 'nope' } "Unknown preset 'nope'"
}

Test 'subset keeps the PM first and rejects unknown names' {
    $ctx = Get-TeamContext (Read-TeamConfig (Join-Path (Get-TeamFixture) '.claude\team.json')) 'E:\x\y'
    Assert-Equal @('pm', 'reviewer') @(Select-TeamMembers $ctx @('reviewer') | ForEach-Object { $_.Name })
    Assert-Equal @('pm', 'dev', 'reviewer') @(Select-TeamMembers $ctx @() | ForEach-Object { $_.Name })
    Assert-Throws { Select-TeamMembers $ctx @('ghost') } "Unknown member 'ghost'"
}

Test 'dry run writes team files but no worktrees or sessions' {
    $repo = Get-TeamFixture
    [void](Invoke-TeamMode -Rest @() -Repo $repo -Base 'main' -Preset 'basic' -DryRun)
    $team = Join-Path "$repo-worktrees" '_team'
    foreach ($f in 'protocol.md', 'launch\pm.ps1', 'launch\dev.ps1', 'settings\reviewer.json', '.claude\agents\pm.md') {
        Assert-True (Test-Path (Join-Path $team $f)) "$f should exist"
    }
    Assert-True (-not (Test-Path (Join-Path "$repo-worktrees" 'crew-pm'))) 'no worktree in dry run'
    Assert-True (-not (Test-Path (Join-Path $team 'sessions.json'))) 'no sessions.json in dry run'
}

Test 'running from a member worktree uses the same team folder' {
    $repo = Get-TeamFixture
    $wt = Join-Path "$repo-worktrees" 'crew-dev'
    git -C $repo worktree add -q -b team/crew-dev $wt 2>$null
    [void](Invoke-TeamMode -Rest @() -Repo $wt -Base 'main' -Preset 'basic' -DryRun)
    Assert-True (Test-Path (Join-Path "$repo-worktrees" '_team\protocol.md')) 'team folder next to the main checkout'
}

Test 'invalid team.json stops with the list of problems' {
    $repo = Get-TeamFixture
    Set-Content (Join-Path $repo '.claude\team.json') '{ "team": "crew", "members": [ { "name": "pm", "agent": "ghost", "model": "sonnet" } ] }'
    Assert-Throws { Invoke-TeamMode -Rest @() -Repo $repo -Base 'main' -Preset 'basic' -DryRun } 'team.json has problems'
}

Test 'dirty main checkout blocks a member in main unless forced' {
    $repo = Get-TeamFixture
    Set-Content (Join-Path $repo '.claude\team.json') '{ "team": "crew", "members": [ { "name": "pm", "agent": "pm", "model": "sonnet" }, { "name": "dev", "agent": "dev", "model": "sonnet", "workspace": "main" } ] }'
    Assert-Throws { Invoke-TeamMode -Rest @() -Repo $repo -Base 'main' -Preset 'basic' -DryRun } 'uncommitted changes'
    [void](Invoke-TeamMode -Rest @() -Repo $repo -Base 'main' -Preset 'basic' -DryRun -Force)
}

Test 'project team-rules.md is inlined into the protocol' {
    $repo = Get-TeamFixture
    Set-Content (Join-Path $repo '.claude\team-rules.md') 'Always say banana.'
    [void](Invoke-TeamMode -Rest @() -Repo $repo -Base 'main' -Preset 'basic' -DryRun -Force)
    Assert-Match (Get-Content -Raw (Join-Path "$repo-worktrees" '_team\protocol.md')) 'Always say banana.'
}

Test 'main checkout clean check' {
    $repo = New-TempRepo
    Assert-True (Test-MainCheckoutClean $repo) 'clean'
    Set-Content (Join-Path $repo 'b.txt') 'y'
    Assert-True (-not (Test-MainCheckoutClean $repo)) 'dirty'
}

Test 'members already running are skipped with a warning' {
    $ctx = Get-TeamContext (Read-TeamConfig (Join-Path (Get-TeamFixture) '.claude\team.json')) 'E:\x\y'
    $r = Remove-RunningMembers @($ctx.Members) @('crew-pm')
    Assert-Equal @('dev', 'reviewer') @($r.Members | ForEach-Object { $_.Name })
    Assert-Match ($r.Warnings -join ';') 'crew-pm is already running'
}

Test 'start.json is written only when safe' {
    Assert-True (Test-ShouldWriteStart $false $false 'main') 'missing file, on a branch'
    Assert-True (-not (Test-ShouldWriteStart $false $false '')) 'missing file, detached HEAD'
    Assert-True (Test-ShouldWriteStart $true $true 'main') 'main member launched, on a branch'
    Assert-True (-not (Test-ShouldWriteStart $true $false 'main')) 'existing file, main member not launched'
}

Test 'config falls back to the main checkout when the worktree has none' {
    $repo = New-TempRepo
    $first = (git -C $repo rev-parse HEAD)
    [void](Invoke-TeamInit $repo 'basic')
    git -C $repo add -A
    git -C $repo -c user.email=t@t -c user.name=t commit -q -m team
    $wt = "$repo-old"
    git -C $repo worktree add -q -b old $wt $first 2>$null
    [void](Invoke-TeamMode -Rest @() -Repo $wt -Base 'main' -Preset 'basic' -DryRun)
    Assert-True (Test-Path (Join-Path "$repo-worktrees" '_team\protocol.md')) 'used the main checkout config'
}
