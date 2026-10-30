# Review findings, 2026-10-28

The code-quality review of `fat` (with `wav` and `sd`), and where each finding stands.

| # | finding | status | commit |
|---|---|---|---|
| wav-fat 2 | No positioned-I/O handle, so every consumer writes the same adapter | fixed: `FileAt[D]` is `sysl.io`'s `ReadAt` + `WriteAt` over an open file (`Error = VolumeError`, `sync` = the volume's flush, a write past the end zero-fills, past 4 GiB − 1 is `TooLarge`); benchtop's `examples/touch` uses it with no adapter | `08e1fb4`, released 0.2.0 |
| wav-fat 3 | The no-allocation claim is unenforced, and `RamDevice` is why | fixed: `RamDevice` works over caller storage, every module file carries `@no_alloc`, and the portable probe is `@no_alloc`; `ImageDevice`'s flush is an fsync; the host's hand-rolled seek+read device is replaced by `StoreDevice` over `sysl.fs.File` | `2d02a9d`, `706f22e`, `7f1d7d9`; `21f099a` |
| wav-fat 4 | The public API exposes the on-disk internals | fixed: `at`, the packed structs, the on-disk constants and the name helpers are `private[fat]`; `File`, `Entry` and `Volume` data are read-only properties | `706f22e`, released 0.3.0 |
| wav-fat 6 | The `sdmmc-bulk-io` branch is not ready to merge | fixed and merged: shared `span` check, the README's `BlockDevice` section, span / cut / overriding-device crash-oracle tests (`32fbf89`, released 0.2.0); the performance point now too: runs go on across clusters contiguous on the disk, reading and writing, and a read's run stops short of a dirty buffered sector instead of falling back for the whole cluster | `32fbf89`; `21f099a` |
| wav-fat 7 | `Volume.write`'s count is all or an error | fixed: a short count where the volume filled, the file reached its largest size or the device failed part way; an error only when nothing was written | `706f22e` |
| wav-fat 8 | Error enums inconsistent and misnamed | fixed: `VolumeError` (was `FsError`), `BootError`, `FormatError`, `DeviceError` one per layer; `DeviceError.Io(code)` carries the driver's code | `706f22e` |
| wav-fat 9 | Hand-rolled helpers that std has | fixed: `sysl.encoding`, `sysl.math.is_power_of_two`, `sysl.slices.fill` (the portable device's zero loop too) | `2d02a9d`; `21f099a` |
| wav-fat 12 | Stale docs and FINDINGS.md history | fixed: manifest header, README dependency block (it had fallen behind again, at 0.4.1), FINDINGS.md removed | `2d02a9d`, `706f22e`; `21f099a` |
| wav-fat 13 | Magic numbers | fixed: `CHAIN_END_MIN16`/`MIN32`, `ATTR_LONG_NAME_MASK`, `LONG_ORDER_MASK` | `2d02a9d` |
| wav-fat 14 | Idiom: redundant suffixes, positional constructors | fixed: `fat_stamp` and `format` without suffixes, named constructor arguments throughout | `2d02a9d` |
| spi-sd 15 | `BlockDevice.sectors(self)` copies the whole `Card` per call | n.a.: a `(self)` method whose body only reads is lent the caller's value by address (`reference/declarations.md`, "A copy is a promise…"), so no copy is made — probed on sysl 0.8.6, a 4 KiB struct's `sectors(self)` through a generic `D` emits `define i64 @Card.sectors(ptr noalias readonly %self.param)` and no `memcpy`; `*self` would only make every caller hold a `var` | — |
