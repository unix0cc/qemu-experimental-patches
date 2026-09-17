#!/bin/sh
# Dump `info tlb` and `info registers` from a running run.sh instance,
# without touching its console.
#   ./tlb.sh pristine|patched [label]
set -eu
W=${1:?pristine|patched}; L=${2:-}
HERE=$(cd "$(dirname "$0")" && pwd)
OUT=$HERE/logs/$W-info-tlb${L:+-$L}-$(date +%Y%m%d-%H%M%S).txt
SOCK=/tmp/0002-ab-$W.mon
{ printf 'info tlb\n'; sleep 1; printf 'info registers\n'; sleep 1; } | nc -U -q 2 "$SOCK" > "$OUT" 2>&1 || true
echo "saved: $OUT"
grep -n -E '256M| 32M| 64k|Tag Access' "$OUT" | head -20
