#!/usr/bin/env bash
# Install a Fologram .xapk (base + split APKs) onto a connected Android device via adb.
# Usage: ./install_fologram.sh path/to/Fologram.xapk
set -euo pipefail
XAPK="${1:?usage: $0 path/to/Fologram.xapk}"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

unzip -q "$XAPK" -d "$TMP"
mapfile -t APKS < <(find "$TMP" -maxdepth 1 -name '*.apk' | sort)
[ ${#APKS[@]} -gt 0 ] || { echo "no .apk inside $XAPK"; exit 1; }

echo "Installing: ${APKS[*]##*/}"
adb install-multiple -r -g "${APKS[@]}"
adb shell dumpsys package com.fologram.android | grep -m1 versionName
