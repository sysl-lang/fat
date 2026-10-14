# fat — roadmap

FAT16 and FAT32 in sysl, for three kinds of consumer at once: keel's `/boot` (firmware reads its boot
files from FAT), skiff's SD card on the STM32H747, and the host's tools. So the package needs no
operating system, allocator or float, and works over a block-device trait.

## Decided

- **The specification is Microsoft's fatgen103** ("FAT: General Overview of On-Disk Format", 1.03).
  Where Linux reads more than the spec allows, the reader follows Linux and the writer the spec (see
  below).
- **FAT16 and FAT32; FAT12 is recognised and refused.** A volume too small for FAT16 (4.1 MB and
  under) is refused by the formatter rather than made FAT12.
- **The formatter chooses the type by size: FAT16 up to 512 MiB, FAT32 above**, with the cluster sizes
  of the spec's `DskTableFAT16`/`DskTableFAT32`. 512 MiB is where the spec's own tables hand over (the
  FAT16 rows past it are "not used unless FAT16 is forced"), and where dosfstools changes too. `-F`
  forces either type within its table's range.
- **Reading, a volume with no 16-bit FAT size is FAT32 whatever its cluster count**, as Linux decides
  it, so the small FAT32 volumes mtools and `mkfs.fat -F 32` make still read. The formatter never makes
  one.
- **The oracles are other implementations**, run in `host/`'s tests: macOS's `fsck_msdos` (the BSDs'),
  dosfstools' `fsck.fat` and `mkfs.fat` (Linux's), mtools' `mformat`. A volume is clean only if both
  checkers say so, and fsck.fat's account of the geometry is compared number for number.
- **The sector size is the device's** (512, 1024, 2048 or 4096); a boot sector naming another is refused.

## Stages

| # | Stage | Done when |
|---|---|---|
| 1 | Format: the boot sector, FSInfo and backup, geometry checks, `mkfs.fat` choosing FAT16 or FAT32 by size | both host checkers find every size clean and fsck.fat agrees with the geometry; mkfs.fat's and mtools' volumes read back; the package builds for five freestanding targets ✅ |
| 2 | Read: FAT chains, directories (short names, long names with their checksum), paths, files, over caller-provided sector buffers | files and directories written by mtools, long names included, read back byte for byte |
| 3 | Write: cluster allocation (FSInfo's hint, both FATs), create, write, extend, truncate, delete, mkdir, rmdir; long names with unique short names (`~N`); times from a clock trait | both checkers find our writes clean and mtools reads every file back |
| 4 | Rename, and writes ordered so a cut leaves at worst lost clusters, never cross-links: a crash-injection device runs every operation cut at every write | fsck.fat repairs every cut image to a volume holding either the old or the new state |
| 5 | Consumers and release: keel mounts its `/boot` (keel ROADMAP row 21), skiff milestone 8; tag v0.1.0 | keel's boot test writes a file there that fsck.fat finds clean |

## Layout

| path | what |
|---|---|
| `sh/sysl/fat/` | the package (module `sh.sysl.fat`): `device` (the trait, a RAM device), `layout` (the on-disk structs), `geometry` (reading and checking a boot sector), `format` |
| `host/` | `fathost`: a block device over an image file, `mkfs.fat`'s command line, and the oracle tests |
| `tools/mkfs-fat/` | the `mkfs.fat` program |
| `tools/portable/` | formats and reads a volume over static memory; built for each freestanding target by the gate |
| `scripts/gate.sh` | the gate: every member's tests, the five freestanding builds, the tool |
