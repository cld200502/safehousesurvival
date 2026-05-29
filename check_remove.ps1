$path = 'c:\Users\丹\CodeBuddy\20260524170342\scripts\autoload\game_manager.gd'
$lines = Get-Content $path
$i = 0
foreach ($line in $lines) {
    $i++
    if ($line -match 'func remove_item|func add_item') {
        Write-Host "$i : $($line.Trim())"
    }
}
