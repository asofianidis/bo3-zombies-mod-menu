#!/usr/bin/env bash
# Prints a SHA-256 of the mod's source files (everything the linker compiles).
# Line endings are normalised so the hash matches tools/source-hash.ps1 on Windows.
# Keep the file list in sync with tools/source-hash.ps1.
set -euo pipefail
root="$(cd "$(dirname "$0")/../zm_modmenu" && pwd)"
cat "$root/scripts/zm/gametypes/_clientids.gsc" \
    "$root/zone_source/zm_mod.zone" | tr -d '\r' | sha256sum | cut -d' ' -f1
