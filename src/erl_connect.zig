const std = @import("std");
const c = @import("c.zig");

pub const ErlConnect = struct {
    conn: *c.ErlConnect,
    fd:   c_int,
    nodename: [:0]u8
};
