Test 'RxC fills unnamed panes with t1..' {
    $a = Get-GridArgs @('2x3')
    Assert-Equal @('t1', 't2', 't3', 't4', 't5', 't6') $a.Names
}

Test 'RxC with names keeps names first' {
    $a = Get-GridArgs @('2x3', 'guard-ai', 'fence-ui')
    Assert-Equal @('guard-ai', 'fence-ui', 't1', 't2', 't3', 't4') $a.Names
}

Test 'names only sets the count' {
    $a = Get-GridArgs @('a', 'b', 'c', '.')
    Assert-Equal 4 $a.Count
}

Test 'auto names skip names already used' {
    $a = Get-GridArgs @('3', 't1')
    Assert-Equal @('t1', 't2', 't3') $a.Names
}

Test 'too many names for RxC throws' {
    Assert-Throws { Get-GridArgs @('1x1', 'a', 'b') } 'has 1 panes but 2 tasks'
}

Test 'no arguments gives count 0' {
    Assert-Equal 0 (Get-GridArgs @()).Count
}
