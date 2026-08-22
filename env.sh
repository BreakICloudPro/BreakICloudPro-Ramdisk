#!/usr/bin/env bash
# Shared paths for BreakICloudPro (A12/A13 SSH ramdisk).

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export NEW_RAMDISK_ROOT="$ROOT"
export NR_VERSION="v1.2-BreakICloudPro"
export NR_AUTHOR="@BreakICloud"
export NR_TELEGRAM="https://t.me/BreakICloud"
export NR_TOOLS="$ROOT/tools/darwin"
export NR_PATCH="$ROOT/patch"
export NR_RESOURCES="$ROOT/resources"
export NR_CACHE="$ROOT/cache"
export NR_WORK="$ROOT/work"
export NR_BOOTCHAIN_ROOT="$ROOT/bootchain"
export PATH="$NR_TOOLS:/opt/homebrew/bin:/usr/local/bin:$PATH:/usr/bin:/bin:/usr/sbin:/sbin"
# shellcheck source=scripts/banner.sh
source "$ROOT/scripts/banner.sh"

# Latest successful bootchain name is written here after build.
export NR_LAST_BOOTCHAIN_FILE="$ROOT/.last_bootchain"
if [[ -z "${BOOTCHAIN_NAME:-}" && -f "$NR_LAST_BOOTCHAIN_FILE" ]]; then
    BOOTCHAIN_NAME="$(<"$NR_LAST_BOOTCHAIN_FILE")"
fi
export BOOTCHAIN_NAME="${BOOTCHAIN_NAME:-}"
export BOOTCHAIN="${BOOTCHAIN_NAME:+$NR_BOOTCHAIN_ROOT/$BOOTCHAIN_NAME}"
