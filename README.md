# fat

FAT16 and FAT32 in [sysl](https://github.com/sysl-lang/sysl): a formatter, reading and writing —
directories, long names and files (see [ROADMAP.md](ROADMAP.md) for what is next). The package needs
no operating system, allocator or float, so the same source runs in a kernel, on a microcontroller with
an SD card, and on the host.

*An independent sysl package for the FAT file system. It is not affiliated with or endorsed by FAT's
authors or trademark holders.*

```hocon
dependencies {
  fat { git = "github.com/sysl-lang/fat", version = "0.2.0" }
}
```

```sysl
import sh.sysl.fat.format

val g = format(&card, label = "CAMERA")?      // FAT16 up to 512 MiB, FAT32 above
```

Reading allocates nothing: the volume reads through one sector the caller hands it, and a file's data
goes straight into the caller's buffer.

```sysl
import sh.sysl.fat.{empty_entry, mount}

var sector: [512]u8 = [0; 512]
var v = mount(&card, sector[..])?

var d = v.open_dir("/photos")?
var e = empty_entry()
while v.read_dir(&d, &e)?
    print(e.name(), e.size)               // long names, as UTF-8

var f = v.open("/photos/Summer holiday.jpg")?
val n = v.read(&f, out)?
```

Names match as Linux matches them: equal but for the case of ASCII letters, by long name or 8.3 name.

Writing goes through the same sector, and **nothing is durable until `flush`**, which also writes
FAT32's free-cluster hint:

```sysl
v.make_dir("/photos/2026")?
var f = v.create("/photos/2026/Holiday at the lake.jpg")?
v.write(&f, jpeg)?                        // grows the file and its chain as it goes
v.truncate(&f, 1024)?
v.rename("/photos/2026/Holiday at the lake.jpg", "/photos/Lake.jpg")?
v.remove("/photos/old.jpg")?
v.remove_dir("/photos/empty")?
v.flush()?
```

A name in 8.3's shape is stored as one; any other gets a run of long-name entries and a unique 8.3
name with a numeric tail (`HOLIDA~1.JPG`), as Windows and Linux write them. Entries are stamped from a
clock the board or kernel supplies (`v.set_clock(&rtc)`, any `Clock`), and with 1980-01-01 without one.

**A power cut leaves at worst lost clusters.** The device sees the writes in the order they are made,
and every operation orders them so that `fsck.fat -a` puts a cut volume back to how it was before the
operation or how it is after — a cluster is made ready before anything points at it, and things are
taken away from the top down. A rename is the one exception FAT allows no way round: cut between writing
the new entry and freeing the old, both names hold the file and fsck keeps it under one of them, unless
both entries are in one sector, as in a rename within a directory with room, where the one write that
carries them makes it whole.

Everything is written against a block-device trait — whole sectors by number, and a flush — so an SD
driver, a virtio disk or an image file is just an implementation:

```sysl
trait BlockDevice
    sector_size(self) -> usize
    sectors(self) -> u64
    read(*self, s: u64, out: []u8) -> Result[unit, DeviceError]
    write(*self, s: u64, data: []const u8) -> Result[unit, DeviceError]
    read_many(*self, sector: u64, out: []u8) -> Result[unit, DeviceError]        // default: `read` per sector
    write_many(*self, sector: u64, bytes: []const u8) -> Result[unit, DeviceError] // default: `write` per sector
    flush(*self) -> Result[unit, DeviceError]
```

A file's data goes to and from the device in runs of whole sectors, up to a cluster at a time, through
`read_many` and `write_many`; a device with a multi-sector command (an SD card's CMD18 and CMD25)
overrides them, and the volume's buffer is written back before every run, so the device still sees the
writes in order. A part of a sector goes through the volume's one sector as before.

An open file is also a positioned store — `sysl.io`'s `ReadAt` and `WriteAt` — so a library written
against those traits takes it with no adapter:

```sysl
import sh.sysl.fat.FileAt

var at = FileAt(&v, v.open("/audio/take 1.wav")?)
val header = read_exact_at(&at, 0, buffer)?
at.write_at(4, size)?                     // past the end, the gap is filled with zeros
at.sync()?                                // the volume's flush
```

## mkfs.fat

```
sysl build tools/mkfs-fat -o mkfs.fat
mkfs.fat -n CAMERA -C card.img 1048576
```

It takes dosfstools' options where both have them (`-F 16|32`, `-s`, `-S`, `-n`, `-i`, `-C`). Left to
choose, it makes FAT16 up to 512 MiB and FAT32 above, with the cluster sizes of the FAT specification's
own tables. FAT12 is not written.

## Tests

`sh scripts/gate.sh`: the package's tests, the host's tests — which check every volume against macOS's
`fsck_msdos` and dosfstools' `fsck.fat` (`brew install dosfstools mtools`), comparing fsck.fat's account
of the geometry number for number, and read back byte for byte every file and directory mtools writes
into our volumes and its own; and the other way round, a tree of files and directories the package
writes — files truncated and removed along the way, a directory grown into reused clusters — must be
clean to both checkers, with every file read back out through mtools by its long name; and every
operation, cut by a device that stops writing after each of its writes in turn, must be repaired by
`fsck.fat -a` to a clean volume the package reads as the one before or the one after. Then the package
built for five freestanding targets, writing included, and the tool.

ISC licence.
