#!/bin/sh
# Build the A/B pair: pristine upstream and upstream + the patch.
#   ./build.sh /path/to/qemu-clone /path/to/0002.patch
# Produces build/pristine/qemu-system-sparc64 and build/patched/qemu-system-sparc64
# next to this script. The clone is not modified; the patched tree is a
# git worktree under build/src-patched.
set -eu
REF=$(cd "${1:?usage: build.sh <qemu-clone> <patch>}" && pwd)
PATCH=$(cd "$(dirname "${2:?usage: build.sh <qemu-clone> <patch>}")" && pwd)/$(basename "$2")
HERE=$(cd "$(dirname "$0")" && pwd)
B=$HERE/build
mkdir -p "$B"

echo "upstream: $(git -C "$REF" rev-parse --short HEAD)"

mkdir -p "$B/pristine" && cd "$B/pristine"
[ -f build.ninja ] || "$REF/configure" --target-list=sparc64-softmmu
make -j"$(nproc)"

[ -d "$B/src-patched" ] || git -C "$REF" worktree add "$B/src-patched" HEAD
if ! git -C "$B/src-patched" log -1 --format=%s | grep -q 'Size<2>'; then
    git -C "$B/src-patched" am "$PATCH"
fi
mkdir -p "$B/patched" && cd "$B/patched"
[ -f build.ninja ] || "$B/src-patched/configure" --target-list=sparc64-softmmu
make -j"$(nproc)"

ls -l "$B/pristine/qemu-system-sparc64" "$B/patched/qemu-system-sparc64"
