//! Snappy frame format implementation.
//!
//! Snappy frames are not part of the core snappy implementation;
//! for raw snappy usage, see [raw.zig](./raw.zig).
//!
//! Reference: https://github.com/google/snappy/blob/main/framing_format.txt

/// Chunk type tags from the Snappy framing format.
const ChunkType = enum(u8) {
    identifier = 0xff,
    compressed = 0x00,
    uncompressed = 0x01,
    padding = 0xfe,
    skippable = 0x80,
};

/// "sNaPpY" identifier payload.
const IDENTIFIER: [6]u8 = [_]u8{ 0x73, 0x4e, 0x61, 0x50, 0x70, 0x59 };

/// Full identifier frame (type + length + payload).
const IDENTIFIER_FRAME: [10]u8 = [_]u8{ 0xff, 0x06, 0x00, 0x00, 0x73, 0x4e, 0x61, 0x50, 0x70, 0x59 };

/// Max allowed size for an uncompressed payload according to the spec.
const UNCOMPRESSED_CHUNK_SIZE_LIMIT = 65536;

pub const UncompressError = error{
    BadIdentifier,
    BadChecksum,
    IllegalChunkLength,
} || snappy.Error || std.mem.Allocator.Error;

pub const CompressError = std.mem.Allocator.Error || snappy.Error;

/// Frame `bytes` into Snappy chunks, choosing compressed payloads only
/// when they are smaller than their uncompressed counterparts.
///
/// Caller owns the returned memory.
pub fn compress(allocator: std.mem.Allocator, bytes: []const u8) CompressError![]u8 {
    var out = std.ArrayList(u8).init(allocator);
    errdefer out.deinit();
    try out.appendSlice(&IDENTIFIER_FRAME);

    const max_compressed_len = snappy.maxCompressedLength(UNCOMPRESSED_CHUNK_SIZE_LIMIT);
    var compressed_buf = try allocator.alloc(u8, max_compressed_len);
    defer allocator.free(compressed_buf);

    var i: usize = 0;
    while (i < bytes.len) : (i += UNCOMPRESSED_CHUNK_SIZE_LIMIT) {
        const end = @min(i + UNCOMPRESSED_CHUNK_SIZE_LIMIT, bytes.len);
        const chunk = bytes[i..end];

        const compressed_len = try snappy.compress(chunk, compressed_buf);
        const compressed = compressed_buf[0..compressed_len];

        const use_compressed = compressed.len < chunk.len;
        const payload = if (use_compressed) compressed else chunk;
        const chunk_type: ChunkType = if (use_compressed) .compressed else .uncompressed;
        const frame_size = payload.len + 4;

        var header: [4]u8 = .{ @intFromEnum(chunk_type), 0, 0, 0 };
        std.mem.writeInt(u24, header[1..4], @intCast(frame_size), .little);
        try out.appendSlice(&header);

        var checksum: [4]u8 = undefined;
        std.mem.writeInt(u32, &checksum, crc(chunk), .little);
        try out.appendSlice(&checksum);
        try out.appendSlice(payload);
    }

    return out.toOwnedSlice();
}

/// Parse framed Snappy data and return the uncompressed payload,
/// or `null` if the frame explicitly signalled an empty buffer.
///
/// Caller owns the returned memory.
pub fn uncompress(allocator: std.mem.Allocator, bytes: []const u8) UncompressError!?[]const u8 {
    std.debug.assert(bytes.len > IDENTIFIER_FRAME.len);
    // Start of stream always starts with the `IDENTIFIER_FRAME`.
    if (!std.mem.eql(u8, bytes[0..IDENTIFIER_FRAME.len], &IDENTIFIER_FRAME)) {
        return UncompressError.BadIdentifier;
    }

    var slice = bytes[IDENTIFIER_FRAME.len..];

    var out = std.ArrayList(u8).init(allocator);
    errdefer out.deinit();

    while (slice.len > 0) {
        if (slice.len < 4) break;
        const chunk_type: ChunkType = @enumFromInt(slice[0]);

        const frame_size: usize = @intCast(std.mem.readInt(u24, slice[1..4], .little));
        const frame = slice[4 .. 4 + frame_size];
        slice = slice[4 + frame_size ..];

        switch (chunk_type) {
            .compressed => {
                const checksum = frame[0..4];
                const compressed = frame[4..];
                var uncompressed: [UNCOMPRESSED_CHUNK_SIZE_LIMIT]u8 = undefined;
                const uncompressed_len = try snappy.uncompress(compressed, uncompressed[0..]);

                if (crc(uncompressed[0..uncompressed_len]) != std.mem.bytesToValue(u32, checksum)) return UncompressError.BadChecksum;
                try out.appendSlice(uncompressed[0..uncompressed_len]);
            },
            .uncompressed => {
                const checksum = frame[0..4];
                const uncompressed = frame[4..];

                if (uncompressed.len > UNCOMPRESSED_CHUNK_SIZE_LIMIT) {
                    return UncompressError.IllegalChunkLength;
                }
                if (crc(uncompressed) != std.mem.bytesToValue(u32, checksum)) return UncompressError.BadChecksum;
                try out.appendSlice(uncompressed);
            },
            .padding,
            .skippable,
            // The stream identifier chunk can come multiple times in the stream besides
            // the first; if such a chunk shows up, it should simply be ignored, assuming
            // it has the right length and contents.
            .identifier,
            => continue,
        }
    }

    if (out.items.len == 0) return null;

    return try out.toOwnedSlice();
}

/// Masked CRC32C hash used by the Snappy framing format.
fn crc(b: []const u8) u32 {
    const c = std.hash.crc.Crc32Iscsi;
    const hash = c.hash(b);
    return @as(u32, hash >> 15 | hash << 17) +% 0xa282ead8;
}

test "snappy crc - sanity" {
    try std.testing.expect(crc("snappy") == 0x293d0c23);
}

const snappy = @import("./raw.zig");
const std = @import("std");
