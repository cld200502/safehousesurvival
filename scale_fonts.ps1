# One-click scale all font sizes in .gd files
# Usage: .\scale_fonts.ps1 -DryRun -Scale 1.4    (preview)
#        .\scale_fonts.ps1 -Scale 1.4             (apply)

param(
    [float]$Scale = 1.5,
    [switch]$DryRun = $false
)

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$gdFiles = Get-ChildItem -Path "$scriptDir\scripts" -Filter "*.gd" -Recurse

$totalCount = 0
$changedFiles = 0
$prefix = if ($DryRun) { "[PREVIEW] " } else { "" }

Write-Host "${prefix}Scale: ${Scale}x"
Write-Host "${prefix}Files: $($gdFiles.Count)"
Write-Host ""

foreach ($file in $gdFiles) {
    $content = Get-Content -Path $file.FullName -Raw -Encoding UTF8
    $fileCount = 0

    $regex = [regex]'(add_theme_font_size_override\("(?:font_size|normal_font_size)",\s*)(\d+)(\s*\))'
    
    $newContent = $regex.Replace($content, {
        param($m)
        $size = [int]$m.Groups[2].Value
        $newSize = [Math]::Max(10, [Math]::Round($size * $Scale))
        if ($newSize -ne $size) { $script:fileCount++ }
        return $m.Groups[1].Value + $newSize + $m.Groups[3].Value
    })

    if ($fileCount -gt 0) {
        $changedFiles++
        $totalCount += $fileCount
        $rel = $file.FullName.Substring($scriptDir.Length + 1)
        if (-not $DryRun) {
            Set-Content -Path $file.FullName -Value $newContent -Encoding UTF8 -NoNewline
        }
        Write-Host "  $rel : $fileCount font sizes"
    }
}

Write-Host ""
Write-Host "${prefix}Done: $changedFiles files, $totalCount font sizes changed"
if (-not $DryRun) { Write-Host "Refresh Godot to see changes!" }
if ($DryRun) { Write-Host "Remove -DryRun to apply." }
