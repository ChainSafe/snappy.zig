# snappy.zig

A Zig library providing bindings to the [Google Snappy compression library](https://github.com/google/snappy), a fast compression/decompression library that aims for high speeds and reasonable compression ratios.

The [Snappy framing format](https://github.com/google/snappy/blob/main/framing_format.txt) is supported in this library.


Requires `0.14.0` or later.

## Usage

Add the dependency to your project:

```sh
zig fetch --save=snappy git+https://github.com/chainsafe/snappy.zig
```

This dependency includes:

- the `"snappy"` module - a zig module providing idiomatic zig bindings to the original snappy (`raw.zig`) and optional snappy frames support (`frame.zig`)
- the `"snappy"` artifact - the upstream snappy static library and headers

In your `build.zig`, add the module:

```zig
const snappy_dep = b.dependency("snappy", .{});

const snappy_mod = snappy_dep.module("snappy");

const snappy_lib = snappy_dep.artifact("snappy");
```

Import `snappy` and use the functions. You can choose between using `raw` or `frame` compression/decompression:

```zig
const snappy = @import("snappy").raw;
// or const snappy = @import("snappy").frame;
```

An example using the `raw` library:

```zig
const snappy = @import("snappy");

const input = "Hello, world!";
const compressed = try allocator.alloc(u8, snappy.maxCompressedLength(input.len));
defer allocator.free(compressed);

const compressed_len = try snappy.raw.compress(input, compressed);
const uncompressed = try allocator.alloc(u8, try snappy.uncompressedLength(compressed[0..compressed_len]));
defer allocator.free(uncompressed);

const uncompressed_len = try snappy.raw.uncompress(compressed[0..compressed_len], uncompressed);
```

An example using the `frame` library:

```zig
const snappy = @import("snappy");

const input = "Hello, world!";
const compressed = try snappy.frame.compress(allocator, input);
defer allocator.free(compressed);

var buf = std.ArrayList(u8).init(allocator);
defer buf.deinit();
const slice = (try snappy.frame.uncompress(compressed, &buf)).?;
defer allocator.free(slice);
```

## API

### `raw`

Supports raw snappy compression and decompression.

- `compress(input: []const u8, compressed: []u8) Error!usize`: Compresses input data into compressed buffer. Returns compressed length.
- `uncompress(compressed: []const u8, uncompressed: []u8) Error!usize`: Decompresses compressed data into uncompressed buffer. Returns uncompressed length.
- `maxCompressedLength(source_length: usize) usize`: Returns the maximum possible compressed size for given input length.
- `uncompressedLength(compressed: []const u8) Error!usize`: Returns the uncompressed length of compressed data.
- `validateCompressedBuffer(compressed: []const u8) Error!void`: Validates if compressed data is valid.

### `frame`

Supports snappy frames compression and decompression.

- `compress(allocator: std.mem.Allocator, bytes: []const u8) CompressError![]u8`: Frame `bytes` into Snappy chunks, choosing compressed payloads only
when they are smaller than their uncompressed counterparts.

- `uncompress(chunk: []const u8, out: *std.ArrayList(u8)) UncompressError!?[]const u8`: Parse framed Snappy data and return the uncompressed payload,
or `null` if the frame explicitly signalled an empty buffer.

## License

MIT
