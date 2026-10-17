# fat

FAT16 and FAT32 in [sysl](https://github.com/sysl-lang/sysl): a formatter, reading and writing —
directories, long names and files (see [ROADMAP.md](ROADMAP.md) for what is next). The package needs
no operating system, allocator or float, so the same source runs in a kernel, on a microcontroller with
an SD card, and on the host.

*An independent sysl package for the FAT file system. It is not affiliated with or endorsed by FAT's
authors or trademark holders.*

```hocon
dependencies {
  fat { git = "github.com/sysl-lang/fat", version = "<the first tag>" }
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
v.remove("/photos/old.jpg")?
v.remove_dir("/photos/empty")?
v.flush()?
```

A name in 8.3's shape is stored as one; any other gets a run of long-name entries and a unique 8.3
name with a numeric tail (`HOLIDA~1.JPG`), as Windows and Linux write them. Entries are stamped from a
clock the board or kernel supplies (`v.set_clock(&rtc)`, any `Clock`), and with 1980-01-01 without one.

Everything is written against a block-device trait — whole sectors by number, and a flush — so an SD
driver, a virtio disk or an image file is just an implementation:

```sysl
trait BlockDevice
    sector_size(self) -> usize
    sectors(self) -> u64
    read(*self, s: u64, out: []u8) -> Result[unit, DeviceError]
    write(*self, s: u64, data: []const u8) -> Result[unit, DeviceError]
    flush(*self) -> Result[unit, DeviceError]
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
clean to both checkers, with every file read back out through mtools by its long name. Then the package
built for five freestanding targets, writing included, and the tool.

ISC licence.
