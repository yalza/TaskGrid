function New-ConfigFixture([string]$Json, [hashtable]$Agents = @{ pm = ''; dev = '' }) {
    $dir = Join-Path ([IO.Path]::GetTempPath()) ('tg-cfg-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
    New-Item -ItemType Directory (Join-Path $dir 'agents') | Out-Null
    foreach ($k in $Agents.Keys) {
        $tools = if ($Agents[$k]) { "tools: $($Agents[$k])`n" } else { '' }
        Set-Content -Encoding ascii (Join-Path $dir "agents\$k.md") "---`nname: $k`ndescription: x`n$tools---`nbody"
    }
    $path = Join-Path $dir 'team.json'
    Set-Content -Encoding ascii $path $Json
    return @{ Path = $path; Agents = (Join-Path $dir 'agents') }
}

$validJson = '{ "team": "tt", "members": [ { "name": "pm", "agent": "pm", "model": "sonnet", "advisor": "opus" }, { "name": "dev", "agent": "dev", "model": "sonnet", "effort": "medium" } ] }'

function Get-Problems([string]$Json, [hashtable]$Agents = @{ pm = ''; dev = '' }) {
    $f = New-ConfigFixture $Json $Agents
    return Test-TeamConfig (Read-TeamConfig $f.Path) $f.Agents
}

Test 'valid config has no problems' {
    Assert-Equal 0 (Get-Problems $validJson).Count
}

Test 'config with a UTF-8 BOM still parses' {
    $f = New-ConfigFixture $validJson
    [IO.File]::WriteAllText($f.Path, $validJson, (New-Object Text.UTF8Encoding $true))
    Assert-Equal 'tt' (Read-TeamConfig $f.Path).team
}

Test 'missing file and bad JSON throw' {
    Assert-Throws { Read-TeamConfig 'C:\nope\team.json' } 'Team config not found'
    $f = New-ConfigFixture '{ "team": '
    Assert-Throws { Read-TeamConfig $f.Path } 'Invalid JSON'
}

Test 'unknown fields are reported' {
    $p = Get-Problems '{ "team": "tt", "colour": 1, "members": [ { "name": "pm", "agent": "pm", "model": "sonnet", "x": 1 } ] }'
    Assert-Match ($p -join ';') "unknown field 'colour'"
    Assert-Match ($p -join ';') "member 'pm': unknown field 'x'"
}

Test 'bad names, reserved names and duplicates are reported' {
    $p = Get-Problems '{ "team": "TT", "members": [ { "name": "Pm", "agent": "pm", "model": "sonnet" }, { "name": "init", "agent": "pm", "model": "sonnet" }, { "name": "dev", "agent": "dev", "model": "sonnet" }, { "name": "dev", "agent": "dev", "model": "sonnet" } ] }'
    $all = $p -join ';'
    Assert-Match $all "'team' must match"
    Assert-Match $all "member 'Pm': 'name' must match"
    Assert-Match $all "'init' is a reserved word"
    Assert-Match $all "member 'dev': duplicate name"
}

Test 'missing agent file and missing model are reported' {
    $p = Get-Problems '{ "team": "tt", "members": [ { "name": "qa", "agent": "qa" } ] }'
    $all = $p -join ';'
    Assert-Match $all "'model' is required"
    Assert-Match $all 'agent file not found'
}

Test 'agent tools list must include team tools' {
    $p = Get-Problems '{ "team": "tt", "members": [ { "name": "pm", "agent": "pm", "model": "sonnet" } ] }' @{ pm = 'Read, Grep' }
    Assert-Match ($p -join ';') 'tools list lacks: SendMessage, ListAgents, Edit, Write, Bash'
}

Test 'effort, permission mode and advisor are checked' {
    $p = Get-Problems '{ "team": "tt", "permissionMode": "yolo", "members": [ { "name": "pm", "agent": "pm", "model": "opus", "effort": "huge", "advisor": "sonnet" }, { "name": "dev", "agent": "dev", "model": "haiku", "advisor": "claude-haiku-4-5" } ] }'
    $all = $p -join ';'
    Assert-Match $all "'permissionMode' must be one of"
    Assert-Match $all "'effort' must be one of"
    Assert-Match $all "advisor 'sonnet' is weaker than model 'opus'"
    Assert-Match $all 'Haiku 4.5 cannot be an advisor'
}

Test 'only one unity owner and one main workspace' {
    $p = Get-Problems '{ "team": "tt", "members": [ { "name": "pm", "agent": "pm", "model": "sonnet", "unity": true, "workspace": "main" }, { "name": "dev", "agent": "dev", "model": "sonnet", "unity": true, "workspace": "main" } ] }'
    $all = $p -join ';'
    Assert-Match $all "only one member may have 'unity': true"
    Assert-Match $all "only one member may have 'workspace': 'main'"
}

Test 'workspace other than main is rejected' {
    $p = Get-Problems '{ "team": "tt", "members": [ { "name": "pm", "agent": "pm", "model": "sonnet", "workspace": "D:\\x" } ] }'
    Assert-Match ($p -join ';') "'workspace' must be 'main' or omitted"
}

Test 'model rank orders families' {
    Assert-True ((Get-ModelRank 'haiku') -lt (Get-ModelRank 'claude-sonnet-5-5')) 'haiku < sonnet'
    Assert-True ((Get-ModelRank 'sonnet') -lt (Get-ModelRank 'opus')) 'sonnet < opus'
    Assert-Equal 0 (Get-ModelRank 'mystery-model')
}
