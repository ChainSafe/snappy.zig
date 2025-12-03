const std = @import("std");

const snappy = @import("snappy.zig");
const frame = @import("frame.zig");

pub const encode = frame.encode;
pub const uncompress = frame.uncompress;

test {
    std.testing.refAllDecls(@import("./snappy.zig"));
    std.testing.refAllDecls(@import("./frame.zig"));
}
