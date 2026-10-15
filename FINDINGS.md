# What writing fat found in sysl

Each finding is what was being written, the shortest input that shows it, what happened, what should
have, and what the package does meanwhile. Found against sysl 0.1.0-alpha.12; all five are fixed in 0.1.0-alpha.13.

## 1. A `Buf` cannot be made at a length, filled with a value (gap)

A RAM device needs `n` zero bytes. `Buf` has `push`, `extend` and `buf_with_capacity(n, fill)` — whose
`fill` reserves storage and leaves the length at 0 — but nothing that answers a buffer of `n` copies of
a value, which is Rust's `vec![0; n]` and C's `calloc`:

```sysl
var bytes: Buf[u8] = buf()
for _ in 0..<n
    bytes.push(0)
```

The loop is what `sh.sysl.fat.ram_device` does, and what keel's KFS `ram_device` does too. Wanted: a
`buf_filled(n, v)` (or `resize`).

**Status: Fixed in 0.1.0-alpha.13** — `buf_filled(n, value)` in `sysl.buf`. `ram_device` and the tests'
zero-filled scratch buffers use it; the element type comes from an annotated binding or a return type
(`val scratch: Buf[u8] = buf_filled(512, 0)`), since a bare `0` is an `int`.

## 2. A fixed byte array cannot be written from a string literal (gap)

A boot sector holds `oem: [8]u8 = "MSWIN4.1"` and `fs_type: [8]u8 = "FAT32   "`. C writes
`char oem[8] = "MSWIN4.1";`, Rust `*b"MSWIN4.1"`. sysl has no spelling: an array literal of eight
`u8('M')`s is the only literal form, so the package copies from a string at run time:

```sysl
private text_bytes[const N: usize](s: string) -> [N]u8
    var out: [N]u8 = [0; N]
    for i in 0..<N
        out[i] = s[i]
    out
```

(`format.sysl`). Wanted: a string literal accepted where a `[N]u8` is expected when its length is `N`,
checked at compile time.

**Status: Fixed in 0.1.0-alpha.13** — a string literal is accepted wherever `[N]u8` is expected if its
byte length is exactly N. `text_bytes` is gone; `format.sysl` assigns the literals directly. A wrong
length is refused (`this string literal is 9 bytes and [8]byte holds 8`), checked by hand: a compile
error cannot be pinned from inside a package's tests.

## 3. A copy through a slice of module storage is refused inside a method, in a hosted build only (bug)

```sysl
import sysl.slices.copy

var storage: [64]u8

struct D
    n: int

    into_storage(*self, data: []const u8)
        copy(storage[0..<8], data)

@export("main")
probe() -> i32
    var out: [8]u8 = [0; 8]
    var d = D(1)
    d.into_storage(out[..])
    i32(out[0])
```

`sysl build` says:

```
error: no 'sysl.slices.copy' takes these arguments — the declarations of that name are:
    sysl.slices.copy(dst: []T, src: []const T)
    sysl.slices.copy(dst: []u8, src: []const u8)
```

The same body in a free function builds, the same file under `sysl build-c` (same host target)
builds, and copying from a local array or a parameter inside the method builds. Moving the free
functions in beside it shows why: the hosted build reads a headerless root file as a script, so its
`var` is a local of an implied `main`, a free function becomes a nested one (`'load' is declared
inside a function body`), and a method cannot see the local at all — which the overload diagnostic
reports as no `copy` matching. **This is skiff's FINDINGS 3** ("a bare-metal program's file can hold no
module storage"), already in sysl's alpha.13 work as root-file storage; the reduction here is a second
shape of it, and the diagnostic naming no reason is worth fixing with it.

Nothing is worked around: `tools/portable` keeps its device in a module of its own (`device/`), which is
where a device belongs anyway.

**Status: Fixed in 0.1.0-alpha.13** — the reduction above builds under `sysl build`. `tools/portable`
keeps its device in `device/` regardless, since that is where a device belongs.

## 4. `()` is not a pattern, so `Ok(())` cannot be matched (gap)

Opening a directory by path answers the root when the path names no entry, so `open_dir` matches on
what `find` (a `Result[unit, FsError]`) answered:

```sysl
check(n: int) -> Result[unit, string] = if n > 0 then Ok(()) else Err("negative")

check(1) match
    Ok(()) -> print("ok")
    Err(e) -> print(e)
```

```
error: '(…)' matches a tuple, but the value is unit
```

`()` builds the unit value, so it reads as the pattern for it too (Rust, Swift and OCaml all accept
it); the reference's patterns page says nothing either way. The library writes `Ok(_)` everywhere, and
so does `volume.sysl` meanwhile.

**Status: Fixed in 0.1.0-alpha.13** — `Ok(())` matches. `Volume.open_dir` matches `find` with it.

## 5. `unit` has no `Eq`, so a `Result[unit, E]` cannot be compared (gap)

```sysl
check(n: int) -> Result[unit, string] = if n > 0 then Ok(()) else Err("negative")

print(check(-1) == Err("negative"))
```

```
error: '==' between sysl.Result[unit, string] needs 'sysl.Eq' — the 'impl' that covers it asks 'sysl.Eq' of unit, which does not implement it
```

The same refusal comes from `assert_eq(v.find("missing", &e), Err(FsError.NotFound))`. `unit` has one
value, so its `Eq` is `true`. The tests compare `.err()` (an `Option[FsError]`) meanwhile.

**Status: Fixed in 0.1.0-alpha.13** — `assert_eq(v.find("missing", &e), Err(FsError.NotFound))` compiles.
The `find` tests compare directly; the tests on `open`, `open_dir` and `mount` keep `.err()`, since their
`Ok` types (`File`, `Dir`, `Volume`) are not comparable.
