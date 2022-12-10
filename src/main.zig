const std = @import("std");
const c = @import("c.zig");

const EI = @import("ei.zig");
const Node = @import("node.zig").Node;

pub fn main() !void {
    try EI.init();

    var node = try Node.init(
        "127.0.0.1", 
        "zig", 
        "zig@127.0.0.1",
        "SECRET_COOKIE",
        std.heap.page_allocator
    );
    defer node.deinit();

    try node.listen();
    std.log.info("Node up {s} at {?d}", .{node.nodename, node.port});

    var conn = try node.accept(5000);
    defer node.close(conn);
    std.log.info("Node connection: {s}", .{conn.nodename});

    while(true) {}
}

test "basic useage" {
    try EI.init();
    var node = try Node.init(
        "127.0.0.1", 
        "zig", 
        "zig@127.0.0.1",
        "SECRET_COOKIE",
        std.testing.allocator
    );
    defer node.deinit();

    try node.listen();
    std.log.info("Node up {s} at {?d}", .{node.nodename, node.port});
}