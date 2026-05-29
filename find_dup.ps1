$filePath = Join-Path $env:USERPROFILE "CodeBuddy\20260524170342\scripts\components\ui_manager.gd"
$content = [System.IO.File]::ReadAllText($filePath, [System.Text.Encoding]::UTF8)
$lines = $content -split "`n"
$lineNum = 0
foreach ($line in $lines) {
    $lineNum++
    if ($line -match "func _npc_qte_check_result|func _build_horde_panel") {
        Write-Host "${lineNum}: $($line.TrimEnd())"
    }
}
