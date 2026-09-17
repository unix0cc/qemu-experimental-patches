#!/bin/sh
# Boot one side of the A/B pair with the console captured and a second
# monitor on a unix socket for tlb.sh.
#   ./run.sh pristine|patched [repro-dir]
# repro-dir is where verify.sh --fetch-only put the six files and the ISO
# (default ../repro). Console log lands in logs/.
set -eu
W=${1:?pristine|patched}
HERE=$(cd "$(dirname "$0")" && pwd)
DIR=$(cd "${2:-$HERE/../repro}" && pwd)
BIN=$HERE/build/$W/qemu-system-sparc64
[ -x "$BIN" ] || { echo "no $BIN -- run build.sh first" >&2; exit 1; }
mkdir -p "$HERE/logs"
LOG=$HERE/logs/$W-console-$(date +%Y%m%d-%H%M%S).txt
SOCK=/tmp/0002-ab-$W.mon; rm -f "$SOCK"
echo "binary: $BIN"; echo "console log: $LOG"; echo "monitor socket: $SOCK"
cd "$DIR"
exec script -q -c "$BIN -M niagara -m 4096 -nographic -serial mon:stdio -L . -trace load_file \
  -monitor unix:$SOCK,server,nowait \
  -drive if=pflash,readonly=on,file=osol-dev-134-ai-sparc.iso" "$LOG"
