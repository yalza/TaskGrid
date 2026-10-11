# "grid team": open a team of role-based Claude sessions (spec sections 4, 7, 9).

$script:TaskGridRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path

function Invoke-TeamInit([string]$RepoRoot, [string]$Preset) {
    $presets = Join-Path $script:TaskGridRoot 'templates\presets'
    $src = Join-Path $presets $Preset
    if (-not (Test-Path $src)) {
        $names = (Get-ChildItem $presets -Directory | ForEach-Object { $_.Name }) -join ', '
        throw "Unknown preset '$Preset'. Available: $names"
    }
    $claudeDir = Join-Path $RepoRoot '.claude'
    $agentsDir = Join-Path $claudeDir 'agents'
    New-Item -ItemType Directory -Force $agentsDir | Out-Null

    $pairs = @(@{ From = (Join-Path $src 'team.json'); To = (Join-Path $claudeDir 'team.json') })
    if (Test-Path (Join-Path $src 'team-rules.md')) {
        $pairs += @{ From = (Join-Path $src 'team-rules.md'); To = (Join-Path $claudeDir 'team-rules.md') }
    }
    $presetConfig = Get-Content -Raw (Join-Path $src 'team.json') | ConvertFrom-Json
    foreach ($agent in @($presetConfig.members | ForEach-Object { $_.agent } | Sort-Object -Unique)) {
        $pairs += @{ From = (Join-Path $script:TaskGridRoot "templates\agents\$agent.md"); To = (Join-Path $agentsDir "$agent.md") }
    }
    foreach ($p in $pairs) {
        if (Test-Path -LiteralPath $p.To) { Write-Host "keep    $($p.To)" }
        else { Copy-Item -LiteralPath $p.From -Destination $p.To; Write-Host "create  $($p.To)" }
    }
    Write-Host ''
    Write-Host 'Edit .claude/team.json (members, models), commit it, then run: grid team'
    return 0
}

# Members to open, PM first. With no names, the whole team.
function Select-TeamMembers($Ctx, [string[]]$Names) {
    $all = @($Ctx.Members)
    $pm = @($all | Where-Object { $_.Agent -eq 'pm' } | Select-Object -First 1)
    $picked = @()
    if (@($Names).Count -eq 0) { $picked = $all }
    else {
        foreach ($n in $Names) {
            if (-not ($all | Where-Object { $_.Name -eq $n })) {
                throw "Unknown member '$n'. Members: $(($all | ForEach-Object { $_.Name }) -join ', ')"
            }
        }
        $picked = @($all | Where-Object { $Names -contains $_.Name -or ($pm.Count -gt 0 -and $_.Name -eq $pm[0].Name) })
    }
    if ($pm.Count -gt 0) {
        $picked = @($pm[0]) + @($picked | Where-Object { $_.Name -ne $pm[0].Name })
    }
    return , $picked
}

function Test-MainCheckoutClean([string]$RepoRoot) {
    $status = git -C $RepoRoot status --porcelain
    return -not $status
}

# Session names (--name) of claude processes running on this machine.
function Get-RunningSessionNames {
    $names = @()
    foreach ($p in @(Get-CimInstance Win32_Process -Filter "Name='claude.exe'" -ErrorAction SilentlyContinue)) {
        if ($p.CommandLine -match '--name\s+"?([^"\s]+)') { $names += $Matches[1] }
    }
    return , $names
}

# A member that is already running must not be launched twice: two processes would share
# one session id and one messaging name.
function Remove-RunningMembers([object[]]$Members, [string[]]$RunningNames) {
    $keep = @()
    $warnings = @()
    foreach ($m in $Members) {
        if (@($RunningNames) -contains $m.SessionName) { $warnings += "$($m.SessionName) is already running; not opening it again." }
        else { $keep += $m }
    }
    return @{ Members = $keep; Warnings = $warnings }
}

# start.json records where the main checkout was when the team started. Rewriting it while
# the Unity owner is mid-check (detached HEAD) would lose that branch.
function Test-ShouldWriteStart([bool]$Exists, [bool]$MainMemberLaunched, [string]$Branch) {
    if (-not $Branch) { return $false }
    return (-not $Exists) -or $MainMemberLaunched
}

function Invoke-TeamMode {
    param(
        [string[]]$Rest = @(),
        [string]$Repo,
        [string]$Base = 'origin/main',
        [string]$Preset = 'basic',
        [switch]$Resume,
        [switch]$DryRun,
        [switch]$Force
    )
    # Config comes from the checkout you run in (so a feature worktree can carry new config);
    # the team folder, worktrees and start.json belong to the main checkout.
    $repoRoot = Resolve-RepoRoot $Repo
    $checkout = Resolve-CheckoutTop $Repo
    if (@($Rest).Count -gt 0 -and $Rest[0] -eq 'init') { return (Invoke-TeamInit $checkout $Preset) }

    # A member worktree on an older base may not have the config yet; use the main checkout's.
    $claudeDir = Join-Path $checkout '.claude'
    if (-not (Test-Path (Join-Path $claudeDir 'team.json')) -and (Test-Path (Join-Path $repoRoot '.claude\team.json'))) {
        $claudeDir = Join-Path $repoRoot '.claude'
    }
    Write-Host "Config: $(Join-Path $claudeDir 'team.json')"
    $config = Read-TeamConfig (Join-Path $claudeDir 'team.json')
    $problems = Test-TeamConfig $config (Join-Path $claudeDir 'agents')
    if ($problems.Count -gt 0) { throw ("team.json has problems:`n  - " + ($problems -join "`n  - ")) }

    $ctx = Get-TeamContext $config $repoRoot
    $members = Select-TeamMembers $ctx @($Rest)
    $notRunning = Remove-RunningMembers $members (Get-RunningSessionNames)
    foreach ($w in $notRunning.Warnings) { Write-Warning $w }
    $members = @($notRunning.Members)
    if ($members.Count -eq 0) {
        Write-Host 'Every selected member is already running.'
        return 0
    }

    if (@($members | Where-Object { $_.IsMain }).Count -gt 0 -and -not (Test-MainCheckoutClean $repoRoot)) {
        if (-not $Force) { throw "The main checkout $repoRoot has uncommitted changes, and a member works there. Commit or stash them, or rerun with -Force." }
        Write-Warning 'The main checkout has uncommitted changes (-Force).'
    }

    # Team folder: protocol, agent copies (loaded through --add-dir), settings, launch scripts.
    $team = $ctx.TeamDir
    foreach ($d in 'tasks', 'out', 'launch', 'settings', '.claude\agents') { New-Item -ItemType Directory -Force (Join-Path $team $d) | Out-Null }
    foreach ($a in @($ctx.Members | ForEach-Object { $_.Agent } | Sort-Object -Unique)) {
        Copy-Item -LiteralPath (Join-Path $claudeDir "agents\$a.md") -Destination (Join-Path $team ".claude\agents\$a.md") -Force
    }
    $rulesPath = Join-Path $claudeDir 'team-rules.md'
    $rules = ''
    if (Test-Path -LiteralPath $rulesPath) { $rules = [IO.File]::ReadAllText($rulesPath) }
    $protocol = New-ProtocolText $ctx $rules (Join-Path $script:TaskGridRoot 'templates\protocol.md')
    Write-Utf8File (Join-Path $team 'protocol.md') $protocol
    $hash = Get-TextHash $protocol

    $sessionsPath = Join-Path $team 'sessions.json'
    $sessions = Read-Sessions $sessionsPath
    $workspaces = @{}
    foreach ($m in $ctx.Members) { $workspaces[$m.Name] = $m.Workspace }
    $hasTranscript = { param($name, $id) Test-Path (Get-TranscriptPath $workspaces[$name] $id) }.GetNewClosure()
    $plan = Get-ResumePlan $sessions @($members | ForEach-Object { $_.Name }) $hash ([bool]$Resume) $hasTranscript
    foreach ($w in $plan.Warnings) { Write-Warning $w }

    foreach ($m in $members) {
        $e = $plan.Entries[$m.Name]
        Write-Utf8File (Join-Path $team "settings\$($m.Name).json") ((New-MemberSettings $ctx $m | ConvertTo-Json -Depth 5) + "`n")
        # BOM: Windows PowerShell 5.1 reads a BOM-less script as ANSI and mangles non-ASCII paths.
        Write-Utf8File (Join-Path $team "launch\$($m.Name).ps1") (New-LaunchScript $ctx $m $e.Id $e.Resume) -Bom
    }

    if ($DryRun) {
        Write-Host "Team '$($ctx.Team)', folder $team"
        foreach ($m in $members) { Write-Host ("  {0,-24} {1}" -f $m.SessionName, $m.Workspace) }
        Write-Host "Dry run: launch scripts are in $team\launch. Nothing was opened."
        return 0
    }

    if ($Base -like 'origin/*') {
        Write-Host 'Fetching origin...'
        git -C $repoRoot fetch origin --quiet
    }
    $open = @()
    foreach ($m in $members) {
        if ($m.IsMain -or (Initialize-Worktree $repoRoot $m.Workspace $m.Branch $Base $m.Name)) { $open += $m }
    }
    if ($open.Count -eq 0) { return 1 }

    # Record sessions only for members that really open, so -Resume never points at a
    # session that was never created.
    foreach ($m in $open) { $sessions[$m.Name] = @{ Id = $plan.Entries[$m.Name].Id; ProtocolHash = $hash } }
    Write-Sessions $sessionsPath $sessions
    $startPath = Join-Path $team 'start.json'
    $branch = [string](git -C $repoRoot branch --show-current)
    if (Test-ShouldWriteStart (Test-Path $startPath) (@($open | Where-Object { $_.IsMain }).Count -gt 0) $branch) {
        $start = [ordered]@{ branch = $branch; commit = [string](git -C $repoRoot rev-parse HEAD) }
        Write-Utf8File $startPath (($start | ConvertTo-Json) + "`n")
    }

    $paneArgs = @()
    foreach ($m in $open) {
        $paneArgs += , @('--title', $m.SessionName, '--suppressApplicationTitle', '-d', $m.Workspace,
                         'powershell', '-NoExit', '-ExecutionPolicy', 'Bypass', '-File', (Join-Path $team "launch\$($m.Name).ps1"))
    }
    $shape = Get-GridShape $open.Count
    Clear-SessionEnv
    Open-WtGrid ("team-$($ctx.Team)-" + (Get-Date -Format 'HHmmss')) $paneArgs (Get-SplitPlan $open.Count $shape.Cols)

    Write-Host ''
    Write-Host "Opened team '$($ctx.Team)': $(($open | ForEach-Object { $_.SessionName }) -join ', ')"
    Write-Host "Team folder: $team"
    Write-Host 'New worktrees ask "trust this folder" once. Talk to the PM in the first pane.'
    return 0
}
