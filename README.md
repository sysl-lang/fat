# fat

FAT16 and FAT32 in [sysl](https://github.com/sysl-lang/sysl): the on-disk format and a formatter today,
reading and writing files next (see [ROADMAP.md](ROADMAP.md)). The package needs no operating system,
allocator or float, so the same source runs in a kernel, on a microcontroller with an SD card, and on
the host.

```hocon
dependencies {
  fat { git = "github.com/sysl-lang/fat", version = "<the first tag>" }
}
```

```sysl
import sh.sysl.fat.format

val g = format(&card, label = "CAMERA")?      // FAT16 up to 512 MiB, FAT32 above
```

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
of the geometry number for number — the package built for five freestanding targets, and the tool.

ISC licence.
