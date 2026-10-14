#!/bin/sh
# fat's gate, run before every merge to dev:
#
#   1. every member's tests: the package's own, then the host's, which check its volumes against the
#      host's FAT tools (fsck_msdos; dosfstools' fsck.fat and mkfs.fat; mtools' mformat);
#   2. the package built for every freestanding CPU family through tools/portable, which instantiates
#      its generic parts: anything that needs an operating system fails here;
#   3. the mkfs.fat program built.

set -u
root=$(cd "$(dirname "$0")/.." && pwd)
compiler=${FAT_SYSL:-sysl}
failed=0

step() {
    echo "== $*"
    if ! "$@"; then
        echo "FAIL: $*"
        failed=1
    fi
}

step "$compiler" test "$root"
mkdir -p "$root/scratch"
for target in thumbv6m-freestanding thumbv7em-freestanding thumb-freestanding riscv32-freestanding aarch64-freestanding; do
    step "$compiler" build-c "$root/tools/portable" --target "$target" -o "$root/scratch/portable-$target.a"
done
step "$compiler" build "$root/tools/mkfs-fat" -o "$root/scratch/mkfs.fat"

if [ "$failed" -eq 0 ]; then echo "GATE: green"; else echo "GATE: red"; fi
exit $failed
