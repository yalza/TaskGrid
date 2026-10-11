foreach ($preset in 'basic', 'unity-game') {
    Test "preset $preset initialises into a valid team" {
        $repo = New-TempRepo
        [void](Invoke-TeamInit $repo $preset)
        $problems = Test-TeamConfig (Read-TeamConfig (Join-Path $repo '.claude\team.json')) (Join-Path $repo '.claude\agents')
        Assert-Equal 0 $problems.Count ("problems: " + ($problems -join '; '))
    }
}

Test 'every role template has a body and no tools list' {
    $dir = Join-Path (Split-Path $PSScriptRoot -Parent) 'templates\agents'
    foreach ($f in Get-ChildItem $dir -Filter *.md) {
        $text = Get-Content -Raw $f.FullName
        Assert-Match $text "(?m)^name: $($f.BaseName)\r?$"
        Assert-True ($null -eq (Get-AgentTools $f.FullName)) "$($f.Name) must not restrict tools"
        Assert-True (($text -split '---', 3)[2].Trim().Length -gt 200) "$($f.Name) needs a real body"
    }
}

Test 'unity-game preset has one Unity owner in main and Unity rules' {
    $root = Join-Path (Split-Path $PSScriptRoot -Parent) 'templates\presets\unity-game'
    $cfg = Get-Content -Raw (Join-Path $root 'team.json') | ConvertFrom-Json
    $owners = @($cfg.members | Where-Object { $_.unity -eq $true })
    Assert-Equal 1 $owners.Count 'unity owners'
    Assert-Equal 'main' $owners[0].workspace
    Assert-Match (Get-Content -Raw (Join-Path $root 'team-rules.md')) 'FormerlySerializedAs'
}
