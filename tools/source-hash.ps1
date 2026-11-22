# Prints a SHA-256 of the mod's source files (everything the linker compiles).
# Line endings are normalised so the hash matches tools/source-hash.sh on Linux CI.
# Keep the file list in sync with tools/source-hash.sh.
$root = Join-Path (Split-Path $PSScriptRoot -Parent) "zm_modmenu"
$files = @(
    "scripts/zm/gametypes/_clientids.gsc",
    "zone_source/zm_mod.zone"
)
$text = ($files | ForEach-Object { [IO.File]::ReadAllText((Join-Path $root $_)) }) -join ""
$bytes = [Text.Encoding]::UTF8.GetBytes(($text -replace "`r", ""))
$sha = [Security.Cryptography.SHA256]::Create()
-join ($sha.ComputeHash($bytes) | ForEach-Object { $_.ToString("x2") })
