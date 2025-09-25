# snappy.zig

A Zig library providing bindings to the Google Snappy compression library. Snappy is a fast compression/decompression library that aims for high speeds and reasonable compression ratios.

## Requirements

- Zig 0.14.0 or later

## Usage

1. `zig fetch --save=snappy git+https://github.com/chainsafe/snappy.zig`

2. This dependency includes:
- the `"snappy"` module - a zig module providing idiomatic zig bindings
- the `"snappy"` artifact - the upstream snappy static library and headers

3. In your `build.zig`, add the module:

```zig
const snappy_dep = b.dependency("snappy", .{});

const snappy_mod = snappy_dep.module("snappy");

const snappy_lib = snappy_dep.artifact("snappy");
```

4. Import the module and use the functions:

```zig
const snappy = @import("snappy");

const input = "Hello, world!";
const compressed = try allocator.alloc(u8, snappy.maxCompressedLength(input.len));
defer allocator.free(compressed);

const compressed_len = try snappy.compress(input, compressed);
const uncompressed = try allocator.alloc(u8, try snappy.uncompressedLength(compressed[0..compressed_len]));
defer allocator.free(uncompressed);

const uncompressed_len = try snappy.uncompress(compressed[0..compressed_len], uncompressed);
```

## API

- `compress(input: []const u8, compressed: []u8) Error!usize`: Compresses input data into compressed buffer. Returns compressed length.
- `uncompress(compressed: []const u8, uncompressed: []u8) Error!usize`: Decompresses compressed data into uncompressed buffer. Returns uncompressed length.
- `maxCompressedLength(source_length: usize) usize`: Returns the maximum possible compressed size for given input length.
- `uncompressedLength(compressed: []const u8) Error!usize`: Returns the uncompressed length of compressed data.
- `validateCompressedBuffer(compressed: []const u8) Error!void`: Validates if compressed data is valid.

## License

MIT
