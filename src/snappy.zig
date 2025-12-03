const std = @import("std");

/// Exposes compress and decompress functionality for raw snappy.
pub const raw = @import("raw.zig");

/// Exposes compress and decompress functionality for snappy frames.
pub const frame = @import("frame.zig");

test {
    std.testing.refAllDecls(raw);
    std.testing.refAllDecls(frame);
}

test "round trip - raw" {
    const allocator = std.testing.allocator;

    var dir = try std.fs.cwd().openDir("testdata", .{ .iterate = true });
    defer dir.close();

    var it = dir.iterate();
    while (try it.next()) |entry| {
        if (entry.kind != .file) continue;

        var file = try dir.openFile(entry.name, .{});
        defer file.close();

        const bytes = try file.readToEndAlloc(allocator, std.math.maxInt(usize));
        defer allocator.free(bytes);

        const compressed = try allocator.alloc(u8, raw.maxCompressedLength(bytes.len));
        defer allocator.free(compressed);
        const compressed_len = try raw.compress(bytes, compressed);

        const got = try allocator.alloc(u8, try raw.uncompressedLength(compressed));
        defer allocator.free(got);
        _ = try raw.uncompress(compressed[0..compressed_len], got);

        try std.testing.expect(std.mem.eql(u8, bytes, got));
    }
}

test "round trip - framed" {
    const allocator = std.testing.allocator;

    var dir = try std.fs.cwd().openDir("testdata", .{ .iterate = true });
    defer dir.close();

    var it = dir.iterate();
    while (try it.next()) |entry| {
        if (entry.kind != .file) continue;

        var file = try dir.openFile(entry.name, .{});
        defer file.close();

        const bytes = try file.readToEndAlloc(allocator, std.math.maxInt(usize));
        defer allocator.free(bytes);
        const d = bytes[0..];
        const compressed = try frame.compress(allocator, d[0..]);
        defer allocator.free(compressed);
        var a = std.ArrayList(u8).init(allocator);
        defer a.deinit();
        const got = (try frame.uncompress(compressed, &a)).?;
        defer allocator.free(got);

        try std.testing.expect(std.mem.eql(u8, bytes, got));
    }
}
