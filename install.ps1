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
    [string]$ToolsPath,
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

# --- Locate Mod Tools -------------------------------------------------------
# Usually installed into the game folder, but Steam can also put them in a
# sibling folder named "Call of Duty Black Ops III 455130".
if (-not $ToolsPath) {
    $candidates = @($GamePath, (Join-Path (Split-Path $GamePath -Parent) "Call of Duty Black Ops III 455130"))
    $ToolsPath = $candidates | Where-Object { Test-Path (Join-Path $_ "bin\linker_modtools.exe") } | Select-Object -First 1
}
if (-not $ToolsPath) {
    throw "BO3 Mod Tools not found. Install 'Call of Duty: Black Ops III - Mod Tools' from Steam > Library > Tools (or pass -ToolsPath), then re-run."
}
$ToolsPath = (Resolve-Path $ToolsPath).Path.TrimEnd('\')
Write-Host "Mod Tools:     $ToolsPath"

$linker = Join-Path $ToolsPath "bin\linker_modtools.exe"
$gdtdb  = Join-Path $ToolsPath "gdtdb\gdtdb.exe"

# The linker builds mods inside its own TA_GAME_PATH\mods folder
$BuildDir = Join-Path $ToolsPath "mods\$ModName"
if ($BuildDir -ne $Dest) {
    if (Test-Path $BuildDir) { Remove-Item $BuildDir -Recurse -Force }
    New-Item -ItemType Directory -Force (Join-Path $ToolsPath "mods") | Out-Null
    Copy-Item -Path $Source -Destination (Join-Path $ToolsPath "mods") -Recurse -Force
}

$env:TA_TOOLS_PATH        = "$ToolsPath\"
$env:TA_GAME_PATH         = "$ToolsPath\"
$env:TA_LOCAL_ASSET_CACHE = "$ToolsPath\share\assetconvert\"

if (Test-Path $gdtdb) {
    Write-Host "Updating gdtdb..."
    & $gdtdb /update | Out-Host
}

Write-Host "Linking $ModName (zm_mod)..."
Push-Location (Join-Path $ToolsPath "bin")
try {
    & $linker -language $Language -fs_game $ModName -modsource zm_mod | Out-Host
    $code = $LASTEXITCODE
} finally { Pop-Location }

$ff = Join-Path $BuildDir "zone\zm_mod.ff"
if ($code -ne 0 -or -not (Test-Path $ff)) {
    throw "Build failed (exit code $code). Scroll up for the linker error."
}
Write-Host "Build OK: $ff" -ForegroundColor Green

# Copy the compiled fastfiles into the real game's mods folder
if ($BuildDir -ne $Dest) {
    New-Item -ItemType Directory -Force (Join-Path $Dest "zone") | Out-Null
    Copy-Item -Path (Join-Path $BuildDir "zone\*") -Destination (Join-Path $Dest "zone") -Recurse -Force
    Write-Host "Installed compiled mod to $Dest\zone"
}

# Copy the compiled fastfiles back into the repo so they can be committed and
# released by CI, and record a hash of the sources they were built from.
Copy-Item -Path (Join-Path $BuildDir "zone\*.ff") -Destination (Join-Path $Source "zone") -Force
$hash = & (Join-Path $PSScriptRoot "tools\source-hash.ps1")
Set-Content -Path (Join-Path $Source "zone\build.hash") -Value $hash -NoNewline -Encoding ascii
Write-Host "Updated repo build output (source hash $hash). Commit zm_modmenu\zone to publish a release."

Write-Host ""
Write-Host "To play: start BO3 > Mods > select 'zm_modmenu' > Load, then start any Zombies map."
Write-Host "In game: ADS + Melee opens the menu."

if ($Launch) {
    Start-Process -FilePath (Join-Path $GamePath "BlackOps3.exe") -ArgumentList "+set fs_game $ModName" -WorkingDirectory $GamePath
}
