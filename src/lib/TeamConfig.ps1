# Reading and validating .claude/team.json (spec section 4).

$script:TeamNamePattern = '^[a-z0-9][a-z0-9-]*$'
$script:ReservedNames = @('init', 'team')
$script:Efforts = @('low', 'medium', 'high', 'xhigh', 'max')
$script:PermissionModes = @('acceptEdits', 'auto', 'bypassPermissions', 'manual', 'dontAsk', 'plan')
$script:TopKeys = @('team', 'permissionMode', 'unityTools', 'members')
$script:MemberKeys = @('name', 'agent', 'model', 'effort', 'advisor', 'workspace', 'unity', 'readonly')
$script:RequiredAgentTools = @('SendMessage', 'ListAgents', 'Read', 'Edit', 'Write', 'Bash')
$script:ModelRanks = [ordered]@{ haiku = 1; sonnet = 2; opus = 3; fable = 4 }

function Read-TeamConfig([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path)) { throw "Team config not found: $Path (run: grid team init)" }
    try { return (Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json) }
    catch { throw "Invalid JSON in ${Path}: $($_.Exception.Message)" }
}

function Get-ModelRank([string]$Model) {
    foreach ($k in $script:ModelRanks.Keys) { if ($Model -match $k) { return $script:ModelRanks[$k] } }
    return 0
}

# Tools named on the frontmatter "tools:" line, or $null when the agent sets no tools list.
function Get-AgentTools([string]$AgentFile) {
    $lines = @(Get-Content -LiteralPath $AgentFile)
    if ($lines.Count -eq 0 -or $lines[0].Trim() -ne '---') { return $null }
    for ($i = 1; $i -lt $lines.Count; $i++) {
        if ($lines[$i].Trim() -eq '---') { break }
        if ($lines[$i] -match '^tools:\s*(.+)$') { return @($Matches[1] -split '[,\s]+' | Where-Object { $_ }) }
    }
    return $null
}

function Test-TeamConfig($Config, [string]$AgentsDir) {
    $errors = @()
    foreach ($p in @($Config.PSObject.Properties.Name)) {
        if ($script:TopKeys -notcontains $p) { $errors += "unknown field '$p'" }
    }
    if (-not $Config.team -or $Config.team -cnotmatch $script:TeamNamePattern) {
        $errors += "'team' must match $($script:TeamNamePattern)"
    }
    if ($Config.permissionMode -and $script:PermissionModes -notcontains $Config.permissionMode) {
        $errors += "'permissionMode' must be one of: $($script:PermissionModes -join ', ')"
    }
    $members = @($Config.members | Where-Object { $_ })
    if ($members.Count -eq 0) {
        $errors += "'members' must list at least one member"
        return , $errors
    }

    $seen = @{}
    $unity = 0
    $main = 0
    foreach ($m in $members) {
        $label = if ($m.name) { "member '$($m.name)'" } else { 'a member' }
        foreach ($p in @($m.PSObject.Properties.Name)) {
            if ($script:MemberKeys -notcontains $p) { $errors += "${label}: unknown field '$p'" }
        }
        if (-not $m.name -or $m.name -cnotmatch $script:TeamNamePattern) { $errors += "${label}: 'name' must match $($script:TeamNamePattern)" }
        elseif ($script:ReservedNames -contains $m.name) { $errors += "${label}: '$($m.name)' is a reserved word" }
        elseif ($seen.ContainsKey($m.name)) { $errors += "${label}: duplicate name" }
        else { $seen[$m.name] = $true }

        if (-not $m.model) { $errors += "${label}: 'model' is required" }
        if ($m.effort -and $script:Efforts -notcontains $m.effort) {
            $errors += "${label}: 'effort' must be one of: $($script:Efforts -join ', ')"
        }
        if ($m.advisor) {
            $advisorRank = Get-ModelRank $m.advisor
            $modelRank = Get-ModelRank $m.model
            if ($m.advisor -match 'haiku-4-5|haiku-4\.5') { $errors += "${label}: Haiku 4.5 cannot be an advisor" }
            elseif ($advisorRank -gt 0 -and $modelRank -gt 0 -and $advisorRank -lt $modelRank) {
                $errors += "${label}: advisor '$($m.advisor)' is weaker than model '$($m.model)'"
            }
        }
        if ($m.workspace -and $m.workspace -ne 'main') { $errors += "${label}: 'workspace' must be 'main' or omitted" }
        if ($m.workspace -eq 'main') { $main++ }
        if ($m.unity -eq $true) { $unity++ }

        if (-not $m.agent) { $errors += "${label}: 'agent' is required"; continue }
        $file = Join-Path $AgentsDir "$($m.agent).md"
        if (-not (Test-Path -LiteralPath $file)) { $errors += "${label}: agent file not found: $file"; continue }
        $tools = Get-AgentTools $file
        if ($null -ne $tools) {
            $missing = @($script:RequiredAgentTools | Where-Object { $tools -notcontains $_ })
            if ($missing.Count -gt 0) { $errors += "${label}: agent '$($m.agent)' tools list lacks: $($missing -join ', ')" }
        }
    }
    if ($unity -gt 1) { $errors += "only one member may have 'unity': true" }
    if ($main -gt 1) { $errors += "only one member may have 'workspace': 'main'" }
    return , $errors
}
