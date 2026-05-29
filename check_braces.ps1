$p = Join-Path $PSScriptRoot "scripts\autoload\game_manager.gd"
$c = [System.IO.File]::ReadAllText($p, [System.Text.Encoding]::UTF8)
$open = ([regex]::Matches($c, '\{')).Count
$close = ([regex]::Matches($c, '\}')).Count
[Console]::WriteLine("Braces: open=${open}, close=${close}")
if ($open -ne $close) { exit 1 } else { exit 0 }
