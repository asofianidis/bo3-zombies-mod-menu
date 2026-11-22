# BO3 Zombies Mod Menu

An in-game GSC mod menu for **Call of Duty: Black Ops III Zombies**. It is built as a normal mod with the official BO3 Mod Tools and works on stock and custom zombies maps.

It is for **private / solo / custom games only**. Only the host gets the menu.

## Controls

| Action | Button |
|---|---|
| Open menu | **ADS + Melee** |
| Scroll up / down | **ADS** / **Fire** |
| Select | **Use** (F / X / Square) |
| Back / close | **Melee** |

## Features

- **Player**: God Mode, Infinite Ammo, Zombies Ignore Me, UFO Mode, Infinite Specialist, +10k / +100k / +1M points, Refill Health
- **Weapons**: Pack-a-Punch current weapon, Max Ammo, Take Weapon, Give Weapon. The Give Weapon list is built from the current map's weapon table.
- **Perks**: Give All, Remove All, or any single perk the map has
- **Power-Ups**: spawn any power-up the map supports
- **Zombies & Rounds**: Kill All, One-Hit Kills, Next / Previous Round, jump to round 10/20/30/50/100
- **Map**: Open All Doors & Debris, Turn On Power, End Game
- **Teleport**: Save / Load position, Teleport to crosshair
- **Fun**: Third Person, Super Speed

## Download

Get the prebuilt mod from [**Releases**](../../releases/latest). Extract `zm_modmenu.zip` into `<BO3>\mods\`, so that you end up with `mods\zm_modmenu\zone\zm_mod.ff`. Then start BO3, go to **Mods**, select **zm_modmenu**, press **Load**, and start any Zombies map.

## Build from source

Requirements:
- Black Ops III (Steam)
- **Call of Duty: Black Ops III - Mod Tools**, free in Steam under *Library > Tools*

Run this from the repo folder:

```powershell
.\install.ps1            # copy to <BO3>\mods\zm_modmenu and build it
.\install.ps1 -Launch    # build, then start the game with the mod
```

You can also build it by hand: copy `zm_modmenu` into `<BO3>\mods\`, open **Mod Tools > Launcher**, tick `mods > zm_modmenu > zm_mod`, tick **Link**, and press **Build**.

To play, start Black Ops III, go to **Mods**, select **zm_modmenu**, press **Load**, then start any Zombies map.

## How it works

`zm_modmenu/scripts/zm/gametypes/_clientids.gsc` overrides the stock script of the same name. Every zombies map loads that script through `scripts/zm/_load.gsc`, so the menu runs on every map. The stock client-id logic is kept.

`zone_source/zm_mod.zone` adds the script to the mod's fastfile.

The menu was made with reference to the open-source [Synergy GSC Menu](https://github.com/SyndiShanX/Synergy-GSC-Menu), the decompiled [T7 scripts](https://github.com/shiversoftdev/t7-source), and Treyarch's [ModLauncher](https://github.com/TreyarchGames/ModLauncher).

## Notes

- Only one mod can be loaded at a time.
- How Turn On Power behaves depends on the map, because some maps use unusual power setups.
- A custom map that ships its own `_clientids.gsc` may override this one.

## Releases (CI)

Every push to `main` runs [`.github/workflows/release.yml`](.github/workflows/release.yml), which publishes a release with `zm_modmenu.zip`.

GitHub's cloud runners can't run the BO3 Mod Tools, so the `.ff` files are compiled locally and committed. To change the menu:

1. Edit `zm_modmenu/scripts/zm/gametypes/_clientids.gsc`.
2. Run `.\install.ps1`. It compiles the mod, installs it into your game, and copies the `.ff` files and `build.hash` into `zm_modmenu/zone`.
3. Commit everything, including `zm_modmenu/zone`, and push.

CI checks that `build.hash` matches the current sources. If you forget step 2, the workflow fails instead of releasing a stale build.
