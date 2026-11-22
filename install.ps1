<#
.SYNOPSIS
    Installs and builds the Zombies Mod Menu into Black Ops III.

.DESCRIPTION
    1. Finds the Black Ops III install (Steam libraries) or uses -GamePath.
    2. Copies .\zm_modmenu to <BO3>\mods\zm_modmenu.
    3. Compiles it with the BO3 Mod Tools linker (linker_modtools.exe).

    Requires: Call of Duty: Black Ops III + "Call of Duty: Black Ops III - Mod Tools"
    (free in Steam under Library > Tools).

.EXAMPLE
    .\install.ps1
    .\install.ps1 -GamePath "F:\SteamLibrary\steamapps\common\Call of Duty Black Ops III"
    .\install.ps1 -NoBuild      # copy files only
    .\install.ps1 -Launch       # build, then start BO3 with the mod loaded
#>
param(
    [string]$GamePath,
    [switch]$NoBuild,
    [switch]$Launch,
    [string]$Language = "english"
)

$ErrorActionPreference = "Stop"
$ModName = "zm_modmenu"
$Source = Join-Path $PSScriptRoot $ModName

function Find-BO3 {
    $steam = (Get-ItemProperty "HKCU:\Software\Valve\Steam" -ErrorAction SilentlyContinue).SteamPath
    $libs = @()
    if ($steam) {
        $libs += $steam
        $vdf = Join-Path $steam "steamapps\libraryfolders.vdf"
        if (Test-Path $vdf) {
            foreach ($m in [regex]::Matches((Get-Content $vdf -Raw), '"path"\s+"([^"]+)"')) {
                $libs += $m.Groups[1].Value -replace '\\\\', '\'
            }
        }
    }
    foreach ($lib in ($libs | Select-Object -Unique)) {
        $p = Join-Path $lib "steamapps\common\Call of Duty Black Ops III"
        if (Test-Path (Join-Path $p "BlackOps3.exe")) { return $p }
    }
    return $null
}

if (-not $GamePath) { $GamePath = Find-BO3 }
if (-not $GamePath -or -not (Test-Path (Join-Path $GamePath "BlackOps3.exe"))) {
    throw "Black Ops III not found (BlackOps3.exe missing). Install/finish downloading it, or pass -GamePath."
}
Write-Host "Black Ops III: $GamePath"

# --- Copy mod files ---------------------------------------------------------
$Dest = Join-Path $GamePath "mods\$ModName"
New-Item -ItemType Directory -Force (Join-Path $GamePath "mods") | Out-Null
Copy-Item -Path $Source -Destination (Join-Path $GamePath "mods") -Recurse -Force
Write-Host "Copied mod to $Dest"

if ($NoBuild) { Write-Host "Skipping build (-NoBuild)."; exit 0 }

# --- Build with Mod Tools ---------------------------------------------------
$linker = Join-Path $GamePath "bin\linker_modtools.exe"
$gdtdb  = Join-Path $GamePath "gdtdb\gdtdb.exe"
if (-not (Test-Path $linker)) {
    throw "BO3 Mod Tools not installed ($linker missing). Install 'Call of Duty: Black Ops III - Mod Tools' from Steam > Library > Tools, then re-run."
}

# The Mod Tools expect these environment variables (normally set by the launcher)
$env:TA_TOOLS_PATH = "$GamePath\"
$env:TA_GAME_PATH  = "$GamePath\"

if (Test-Path $gdtdb) {
    Write-Host "Updating gdtdb..."
    & $gdtdb /update | Out-Host
}

Write-Host "Linking $ModName (zm_mod)..."
Push-Location (Join-Path $GamePath "bin")
try {
    & $linker -language $Language -fs_game $ModName -modsource zm_mod | Out-Host
    $code = $LASTEXITCODE
} finally { Pop-Location }

$ff = Join-Path $Dest "zone\zm_mod.ff"
if ($code -ne 0 -or -not (Test-Path $ff)) {
    throw "Build failed (exit code $code). Scroll up for the linker error."
}
Write-Host "Build OK: $ff" -ForegroundColor Green

Write-Host ""
Write-Host "To play: start BO3 > Mods > select 'zm_modmenu' > Load, then start any Zombies map."
Write-Host "In game: ADS + Melee opens the menu."

if ($Launch) {
    Start-Process -FilePath (Join-Path $GamePath "BlackOps3.exe") -ArgumentList "+set fs_game $ModName" -WorkingDirectory $GamePath
}
