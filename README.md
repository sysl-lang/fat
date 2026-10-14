# fat

FAT16 and FAT32 in [sysl](https://github.com/sysl-lang/sysl): a formatter, and reading — directories,
long names and files — today; writing next (see [ROADMAP.md](ROADMAP.md)). The package needs no
operating system, allocator or float, so the same source runs in a kernel, on a microcontroller with an
SD card, and on the host.

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
into our volumes and its own — the package built for five freestanding targets, and the tool.

ISC licence.
