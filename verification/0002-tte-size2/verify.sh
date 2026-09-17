#!/bin/sh
# Reproduce the sun4v 32M/256M TTE page-size bug fixed by
# "target/sparc: implement TTE page-size bit 48 (Size<2>) for 32M/256M pages".
#
# Fetches the six firmware/MD files and the guest ISO into one directory,
# checks their hashes, and boots -M niagara with them. Run it once against
# a pristine qemu-system-sparc64 and once against one with the patch:
#
#   QEMU=/path/to/pristine/qemu-system-sparc64 ./verify.sh
#   QEMU=/path/to/patched/qemu-system-sparc64  ./verify.sh
#
# At the "ok" prompt type: boot
#   pristine: hangs after "Loading: /platform/sun4v/kernel/sparcv9/unix"
#   patched:  boots to "Enter user name for system maintenance"
# Ctrl-a c gives the QEMU monitor (`info tlb`), Ctrl-a x quits.
#
# Options:  --fetch-only   download and verify, don't boot
#           --dir DIR      working directory (default ./repro)

set -eu

QEMU=${QEMU:-qemu-system-sparc64}
DIR=./repro
FETCH_ONLY=0
while [ $# -gt 0 ]; do
    case $1 in
        --fetch-only) FETCH_ONLY=1 ;;
        --dir) DIR=$2; shift ;;
        *) echo "unknown option: $1" >&2; exit 2 ;;
    esac
    shift
done

MD_REPO=https://raw.githubusercontent.com/unix0cc/md
MD_COMMIT=4fa9b7b0793db67d32426eb23f3a9324f3edf74a
MD_PATH=bin/pagesize_256m/4096
T1_TARBALL=http://download.oracle.com/technetwork/systems/opensparc/OpenSPARCT1_Arch.1.5.tar.bz2
ISO_URL=https://mirror.math.princeton.edu/pub/openindiana-iso/archive/opensolaris/osol-dev-134-ai-sparc.iso
ISO=osol-dev-134-ai-sparc.iso

# sha256 of every input; see README for where each comes from
sums='
11c18ef2b054cb7bb48824e421b138517eaad0d459c38dd0cc7dc63d05019a20  1up-md.bin
9df4cf283410633ca0e822cd846a652fea4e59a8f452235490c2fcae9dd296c5  1up-hv.bin
d88c7556b767936c34ad3a4df5774575fc26aa076574deb705c3b9891b1f03b8  openboot.bin
c32afe0ba5ebc29dd83466226456249b37c1a091d7d4b8a45ac9b039c13cc84b  q.bin
942b5c5b83feb55b6e25c491f570a91c62351abf6c325c5b11e79075e320d7fb  reset.bin
6a86841db2b662b5a40dbfe13fc88f334be647984a24cb6a979e9c7717512cf2  nvram1
fe36ae8d3aea3797a10607c0e024c02fe91f99f43f64e5234280b7a0c4e8ab0a  osol-dev-134-ai-sparc.iso
'

mkdir -p "$DIR" && cd "$DIR"

# MD/hv-config pair: built from .pdesc source with mdgen, pinned to a commit
for f in 1up-md.bin 1up-hv.bin; do
    [ -f $f ] || curl -fLO "$MD_REPO/$MD_COMMIT/$MD_PATH/$f"
done

# OBP, hypervisor, reset vector, NVRAM: Sun's originals from the OpenSPARC T1
# archive that docs/system/target-sparc64.rst points at (S10image/)
if [ ! -f openboot.bin ] || [ ! -f q.bin ] || [ ! -f reset.bin ] || [ ! -f nvram1 ]; then
    [ -f OpenSPARCT1_Arch.1.5.tar.bz2 ] || curl -fLO "$T1_TARBALL"
    tar xjf OpenSPARCT1_Arch.1.5.tar.bz2 --strip-components=2 \
        ./S10image/openboot.bin ./S10image/q.bin ./S10image/reset.bin ./S10image/nvram1
fi

[ -f $ISO ] || curl -fLO "$ISO_URL"

echo "$sums" | grep . | sha256sum -c -

[ $FETCH_ONLY = 1 ] && { echo "fetched into $DIR"; exit 0; }

echo "running: $QEMU"
exec "$QEMU" -M niagara -m 4096 -nographic -serial mon:stdio -L . -trace load_file \
    -drive if=pflash,readonly=on,file=$ISO
