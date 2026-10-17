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
- **Reading allocates nothing.** The caller hands `mount` one sector of storage, which every FAT and
  directory read goes through; file data goes straight into the caller's buffer wherever it fills whole
  sectors of it. An entry's name is a view of the entry's own storage.
- **Names match as Linux's vfat matches UTF-8 names**: equal but for the case of ASCII letters, and
  against both the long name and the 8.3 one. Unicode case folding would put the Unicode database into
  every kernel and board that reads a card.
- **Short names are code page 437**, the default of Linux, mtools and dosfstools; the NT case bits are
  honoured.
- **A long name is used only when its run is whole**: it begins with the entry marked last, each entry
  numbers one less with the same checksum, and the checksum is the short entry's. Anything else is
  dropped and the 8.3 name shown, as every reader does.
- **FAT32's active FAT is honoured**: with mirroring off, the FAT its flags name is the one read and
  the only one written; with it on, every FAT write goes to every copy.
- **Writes go through the volume's one sector, written back when another is wanted, and nothing is
  durable until `flush`**, which also writes FAT32's FSInfo (the free count and where to look next).
  A whole sector of file data goes straight to the device, after the sector held.
- **A free cluster is searched for from FSInfo's hint on**, wrapping round; a new cluster is made the end
  of its chain before the chain is linked to it, and a directory's new cluster is zeroed.
- **Short names follow Microsoft's long file name specification**: a name in 8.3's shape is its own
  short name, with the NT bits where its base or extension is all lower case and a long name where either
  is mixed; any other gets the spec's basis name (non-ASCII and `+,;=[]` as `_`, spaces and leading dots
  dropped) and the first free numeric tail, `~1` on. A name is refused when it ends in a space or a dot,
  holds a control or one of `"*/:<>?\|`, or is longer than 255 UTF-16 units.
- **Times come from a `Clock`** the volume is handed; without one an entry says 1980-01-01 00:00:00.
- **The device sees the writes in the order they are made, and each operation orders them for a power
  cut**: a cluster is ready before anything points at it (the end of its chain before it is linked, a
  directory's zeroed before it is linked, a file's entry written last), and things are taken away from
  the top down (an entry's size before its clusters, a short entry before its long-name entries, an
  entry before its clusters). A cut leaves at worst clusters nothing names, a chain longer than its file,
  or long-name entries with no short entry, and `fsck.fat -a` puts the volume back to before or after.
- **A rename writes the new entry before freeing the old**, so a cut between leaves both names on one
  chain, never neither; fsck.fat keeps the file under the name it reaches first and empties the other.
  No order avoids it when the two entries are in different sectors (Linux's vfat has the same window); where they
  share one, the single write makes the rename whole. A directory moved between directories and cut
  there takes fsck.fat three passes (it empties the second name, then deletes its short entry, then its
  long name). A rename onto an existing name is refused, except the entry's own (a change of case).
- **`fsck.fat -a` salvages lost clusters as `FSCK0000.REC`** rather than freeing them, so the crash oracle
  counts those files as fsck's, not as either volume's.

## Stages

| # | Stage | Done when |
|---|---|---|
| 1 | Format: the boot sector, FSInfo and backup, geometry checks, `mkfs.fat` choosing FAT16 or FAT32 by size | both host checkers find every size clean and fsck.fat agrees with the geometry; mkfs.fat's and mtools' volumes read back; the package builds for five freestanding targets ✅ |
| 2 | Read: FAT chains, directories (short names, long names with their checksum), paths, files, over caller-provided sector buffers | files and directories written by mtools, long names included, read back byte for byte ✅ |
| 3 | Write: cluster allocation (FSInfo's hint, both FATs), create, write, extend, truncate, delete, mkdir, rmdir; long names with unique short names (`~N`); times from a clock trait | both checkers find our writes clean and mtools reads every file back ✅ |
| 4 | Rename, and writes ordered for a power cut: a device that stops writing runs every operation cut at every write | fsck.fat repairs every cut image to a clean volume holding the old or the new state — for a rename between directories, both names with the file under one ✅ |
| 5 | Release v0.1.0 | tagged, with release notes ✅ |

**Consumers** take it in their own repos: keel mounts its `/boot` (keel ROADMAP row 21) and skiff's SD
card (milestone 8), each with a boot test that writes a file fsck.fat then finds clean.

## Layout

| path | what |
|---|---|
| `sh/sysl/fat/` | the package (module `sh.sysl.fat`): `device` (the trait, a RAM device), `layout` (the on-disk structs), `geometry` (reading and checking a boot sector), `format`, `names` (8.3 and long names to UTF-8), `volume` (mounting, chains, directories, paths, reading files), `write` (allocation, creating, writing, truncating, renaming and removing, short names, the order of writes), `clock` (time stamps) |
| `host/` | `fathost`: a block device over an image file, `mkfs.fat`'s command line, and the oracle tests (`crash_oracle_tests` cuts every operation at every write) |
| `tools/mkfs-fat/` | the `mkfs.fat` program |
| `tools/portable/` | formats, mounts and reads a volume over static memory; built for each freestanding target by the gate |
| `scripts/gate.sh` | the gate: every member's tests, the five freestanding builds, the tool |
