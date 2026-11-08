#!/usr/bin/env bash
# Package magisk-module/fologram_ar_toggle into an installable zip (LF line endings, '/' paths).
set -euo pipefail
cd "$(dirname "$0")/../magisk-module/fologram_ar_toggle"
OUT="../../fologram_ar_toggle.zip"
rm -f "$OUT"
zip -q -r "$OUT" module.prop action.sh customize.sh META-INF
echo "built $(cd ../.. && pwd)/fologram_ar_toggle.zip"
