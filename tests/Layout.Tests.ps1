Test 'grid shape fits the count' {
    foreach ($case in @(@(1, 1, 1), @(2, 1, 2), @(3, 2, 2), @(4, 2, 2), @(5, 2, 3), @(6, 2, 3), @(9, 3, 3))) {
        $s = Get-GridShape $case[0]
        Assert-Equal "$($case[1])x$($case[2])" "$($s.Rows)x$($s.Cols)" "shape for $($case[0])"
    }
}

Test 'explicit rows and columns win' {
    $s = Get-GridShape 6 3 2
    Assert-Equal '3x2' "$($s.Rows)x$($s.Cols)"
}

Test 'split size is invariant across cultures' {
    $old = [Threading.Thread]::CurrentThread.CurrentCulture
    try {
        [Threading.Thread]::CurrentThread.CurrentCulture = 'vi-VN'
        Assert-Equal '0.6667' (Format-SplitSize 3)
        Assert-Equal '0.5' (Format-SplitSize 2)
    } finally { [Threading.Thread]::CurrentThread.CurrentCulture = $old }
}

Test 'split plan for 5 panes in 3 columns' {
    $plan = Get-SplitPlan 5 3
    $text = ($plan | ForEach-Object { "$($_.From)>$($_.To)$($_.Dir)$($_.K)" }) -join ' '
    Assert-Equal '0>1-V3 1>2-V2 0>3-H2 1>4-H2' $text
}

Test 'split plan for one pane is empty' {
    $plan = Get-SplitPlan 1 1
    Assert-Equal 0 $plan.Count
}

Test 'split plan clamps columns to the count' {
    $plan = Get-SplitPlan 2 3
    Assert-Equal 1 $plan.Count
}
