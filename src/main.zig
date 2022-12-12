const std = @import("std");
const c = @import("c.zig");

const EI = @import("ei.zig");
const Node = @import("node.zig").Node;
const ErlError = @import("erl_error.zig").ErlError;

// TODO: this entire function should be two library functions:
// 1) accept
// 2) for every connection - receive message
// These could be threaded on paper, but i'm unsure if the
// erlang interface allows it. 
pub fn main() !void {
    try EI.init(); 

    // TODO: Node should allow for `hidden` names
    var node = try Node.init("127.0.0.1", "zig", "zig@127.0.0.1", "SECRET_COOKIE", 0, std.heap.page_allocator);
    defer node.deinit();

    try node.listen();
    std.log.info("Node up {s} at {?d}", .{ node.nodename, node.port});
    try node.register_process();

    std.log.info("Awaiting connection", .{});
    while (true) node_accepted: {
            // wait up to 5 seconds for a new connection.
            // return a `ei_accept` error message on timeout
            // Technically, there should be a
            // thread to run "accept", which itself
            // should probably spawn one thread per connection.
            // It's unclear weather the EI library
            // is threadsafe in this model
            var conn = node.accept(5000) catch |err| {
            switch (err) {
                ErlError.ei_accept => continue,
                else => |e| return e,
            }
        };
        defer node.close(&conn);

        // TODO: see above. This loop should likely be in a different thread,
        // as spawned by the Accept call

        std.log.info("Node connection: {s}", .{conn.nodename});

        // TODO: each node should register a few global names.
        // 1) :net_kerrnel - handles internal network ping messages 
        // 2) :rex - for RPC handling
        while (true) {
            // wait up to 100 ms for a new message. Even if there
            // are no messages in the mailbox, other nodes
            // send a TICK message. This message just needs to be
            // received, nothing about it needs to be handled.
            // Returns EIO if the connection to the other node
            // is broken
            var msg = conn.receive(100) catch |err| {
                switch (err) {
                    ErlError.TIMEOUT, ErlError.TICK => continue,
                    ErlError.EIO => {
                        std.log.err("Node disconnected: {s}", .{conn.nodename});
                        break :node_accepted;
                    },
                    else => |e| return e,
                }
            };
            defer msg.deinit();

            // handle the received message
            // std.log.info("Received message: {}", .{msg});
            try node.handle_message(&conn, &msg);
        }
    }
}

// Term Decode Tests
// see the script in the `term_fixtures` dir.
// (nothing in that folder is required at runtime)
// TODO: put these in their own file

const atom_term = @embedFile("term_fixtures/atom.term");

test "decode atom" {
    try EI.init();
    var x: c.ei_x_buff = std.mem.zeroes(c.ei_x_buff);

    var buff = try std.testing.allocator.alloc(u8, atom_term.len);
    defer std.testing.allocator.free(buff);

    std.mem.copy(u8, buff, atom_term);

    x.buff = @ptrCast([*c]u8, buff);

    var term = try EI.Term.init(std.testing.allocator, &x);
    defer term.deinit();
    const expected_atom_value: [:0]const u8 = "hello, world";
    try std.testing.expectFmt(expected_atom_value, "{s}", .{term.value.atom});
}

const big_number_term = @embedFile("term_fixtures/big_number.term");

test "decode big_number" {
    try EI.init();
    var x: c.ei_x_buff = std.mem.zeroes(c.ei_x_buff);

    var buff = try std.testing.allocator.alloc(u8, big_number_term.len);
    defer std.testing.allocator.free(buff);

    std.mem.copy(u8, buff, big_number_term);

    x.buff = @ptrCast([*c]u8, buff);

    var term = try EI.Term.init(std.testing.allocator, &x);
    defer term.deinit();
    try std.testing.expect(term.value.integer == 0xffff);
}

const binary_term = @embedFile("term_fixtures/binary.term");

test "decode binary" {
    try EI.init();
    var x: c.ei_x_buff = std.mem.zeroes(c.ei_x_buff);

    var buff = try std.testing.allocator.alloc(u8, binary_term.len);
    defer std.testing.allocator.free(buff);

    std.mem.copy(u8, buff, binary_term);

    x.buff = @ptrCast([*c]u8, buff);

    var term = try EI.Term.init(std.testing.allocator, &x);
    defer term.deinit();
    try std.testing.expectFmt("hello, world", "{s}", .{term.value.binary});
}

const double_term = @embedFile("term_fixtures/double.term");

test "decode double" {
    try EI.init();
    var x: c.ei_x_buff = std.mem.zeroes(c.ei_x_buff);

    var buff = try std.testing.allocator.alloc(u8, double_term.len);
    defer std.testing.allocator.free(buff);

    std.mem.copy(u8, buff, double_term);

    x.buff = @ptrCast([*c]u8, buff);

    var term = try EI.Term.init(std.testing.allocator, &x);
    defer term.deinit();
    try std.testing.expect(term.value.double == 69.420);
}

const number_term = @embedFile("term_fixtures/number.term");

test "decode number" {
    try EI.init();
    var x: c.ei_x_buff = std.mem.zeroes(c.ei_x_buff);

    var buff = try std.testing.allocator.alloc(u8, number_term.len);
    defer std.testing.allocator.free(buff);

    std.mem.copy(u8, buff, number_term);

    x.buff = @ptrCast([*c]u8, buff);

    var term = try EI.Term.init(std.testing.allocator, &x);
    defer term.deinit();
    try std.testing.expect(term.value.integer == 1);
}

const pid_term = @embedFile("term_fixtures/pid.term");

test "decode pid" {
    try EI.init();
    var x: c.ei_x_buff = std.mem.zeroes(c.ei_x_buff);

    var buff = try std.testing.allocator.alloc(u8, pid_term.len);
    defer std.testing.allocator.free(buff);

    std.mem.copy(u8, buff, pid_term);

    x.buff = @ptrCast([*c]u8, buff);

    var term = try EI.Term.init(std.testing.allocator, &x);
    defer term.deinit();
    try std.testing.expectEqual(c.erlang_pid{ .node = .{ 105, 101, 120, 64, 49, 50, 55, 46, 48, 46, 48, 46, 49, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 }, .num = 112, .serial = 0, .creation = 1670634910 }, term.value.pid);
}

const reference_term = @embedFile("term_fixtures/reference.term");

test "decode reference" {
    try EI.init();
    var x: c.ei_x_buff = std.mem.zeroes(c.ei_x_buff);

    var buff = try std.testing.allocator.alloc(u8, reference_term.len);
    defer std.testing.allocator.free(buff);

    std.mem.copy(u8, buff, reference_term);

    x.buff = @ptrCast([*c]u8, buff);

    var term = try EI.Term.init(std.testing.allocator, &x);
    defer term.deinit();
    try std.testing.expectEqual(c.erlang_ref{ .node = .{ 105, 101, 120, 64, 49, 50, 55, 46, 48, 46, 48, 46, 49, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 }, .len = 3, .n = .{ 261228, 3807903745, 530241391, 0, 0 }, .creation = 1670634910 }, term.value.ref);
}

const string_term = @embedFile("term_fixtures/string.term");

test "decode string" {
    try EI.init();
    var x: c.ei_x_buff = std.mem.zeroes(c.ei_x_buff);

    var buff = try std.testing.allocator.alloc(u8, string_term.len);
    defer std.testing.allocator.free(buff);

    std.mem.copy(u8, buff, string_term);

    x.buff = @ptrCast([*c]u8, buff);

    var term = try EI.Term.init(std.testing.allocator, &x);
    defer term.deinit();
    const expected_string_value = "hello, world";
    try std.testing.expectFmt(expected_string_value, "{s}", .{term.value.string});
}

const simple_tuple_with_atoms = @embedFile("term_fixtures/simple_tuple_with_atoms.term");

test "decode simple_tuple_with_atoms" {
    try EI.init();
    var x: c.ei_x_buff = std.mem.zeroes(c.ei_x_buff);

    var buff = try std.testing.allocator.alloc(u8, simple_tuple_with_atoms.len);
    defer std.testing.allocator.free(buff);

    std.mem.copy(u8, buff, simple_tuple_with_atoms);

    x.buff = @ptrCast([*c]u8, buff);

    var term = try EI.Term.init(std.testing.allocator, &x);
    defer term.deinit();
    std.debug.print("0={s},1={s},2={s}\n", .{
        term.value.tuple[0].atom,
        term.value.tuple[1].atom,
        term.value.tuple[2].atom
    });
    try std.testing.expectFmt(
        "a", 
        "{s}", 
        .{term.value.tuple[0].atom}
    );
    try std.testing.expectFmt(
        "b", 
        "{s}", 
        .{term.value.tuple[1].atom}
    );
    try std.testing.expectFmt(
        "c", 
        "{s}", 
        .{term.value.tuple[2].atom}
    );
}

const simple_tuple_with_strings_and_atoms = @embedFile("term_fixtures/simple_tuple_with_strings_and_atoms.term");

test "decode simple_tuple_with_strings_and_atoms" {
    try EI.init();
    var x: c.ei_x_buff = std.mem.zeroes(c.ei_x_buff);

    var buff = try std.testing.allocator.alloc(u8, simple_tuple_with_strings_and_atoms.len);
    defer std.testing.allocator.free(buff);

    std.mem.copy(u8, buff, simple_tuple_with_strings_and_atoms);

    x.buff = @ptrCast([*c]u8, buff);

    var term = try EI.Term.init(std.testing.allocator, &x);
    defer term.deinit();
    try std.testing.expectFmt(
        "hello", 
        "{s}", 
        .{term.value.tuple[0].string}
    );
    try std.testing.expectFmt(
        "world", 
        "{s}", 
        .{term.value.tuple[1].atom}
    );
}

const simple_tuple_with_strings_and_binaries = @embedFile("term_fixtures/simple_tuple_with_strings_and_binaries.term");

test "decode simple_tuple_with_strings_and_binaries" {
    try EI.init();
    var x: c.ei_x_buff = std.mem.zeroes(c.ei_x_buff);

    var buff = try std.testing.allocator.alloc(u8, simple_tuple_with_strings_and_binaries.len);
    defer std.testing.allocator.free(buff);

    std.mem.copy(u8, buff, simple_tuple_with_strings_and_binaries);

    x.buff = @ptrCast([*c]u8, buff);

    var term = try EI.Term.init(std.testing.allocator, &x);
    defer term.deinit();
    try std.testing.expectFmt(
        "hello", 
        "{s}", 
        .{term.value.tuple[0].string}
    );
    try std.testing.expectFmt(
        "world", 
        "{s}", 
        .{term.value.tuple[1].binary}
    );
}

const map1 = @embedFile("term_fixtures/map1.term");

test "decode map1" {
    try EI.init();
    var x: c.ei_x_buff = std.mem.zeroes(c.ei_x_buff);

    var buff = try std.testing.allocator.alloc(u8, map1.len);
    defer std.testing.allocator.free(buff);

    std.mem.copy(u8, buff, map1);

    x.buff = @ptrCast([*c]u8, buff);

    var term = try EI.Term.init(std.testing.allocator, &x);
    defer term.deinit();

    var value = term.value.map.get(EI.TermValue{.atom = &[_]u8{'a'}});
    try std.testing.expectFmt("b", "{s}", .{value.?.atom});
}

const map2 = @embedFile("term_fixtures/map2.term");

test "decode map2" {
    try EI.init();
    var x: c.ei_x_buff = std.mem.zeroes(c.ei_x_buff);

    var buff = try std.testing.allocator.alloc(u8, map2.len);
    defer std.testing.allocator.free(buff);

    std.mem.copy(u8, buff, map2);

    x.buff = @ptrCast([*c]u8, buff);

    var term = try EI.Term.init(std.testing.allocator, &x);
    defer term.deinit();
    var value = term.value.map.get(EI.TermValue{.atom = &[_]u8{'a'}});
    try std.testing.expectFmt("hello, world", "{s}", .{value.?.string});
}
const map3 = @embedFile("term_fixtures/map3.term");

test "decode map3" {
    try EI.init();
    var x: c.ei_x_buff = std.mem.zeroes(c.ei_x_buff);

    var buff = try std.testing.allocator.alloc(u8, map3.len);
    defer std.testing.allocator.free(buff);

    std.mem.copy(u8, buff, map3);

    x.buff = @ptrCast([*c]u8, buff);

    var term = try EI.Term.init(std.testing.allocator, &x);
    defer term.deinit();
    var value = term.value.map.get(EI.TermValue{.atom = &[_]u8{'a'}});
    try std.testing.expectFmt("hello, world", "{s}", .{value.?.binary});
}

const map4 = @embedFile("term_fixtures/map4.term");

test "decode map4" {
    try EI.init();
    var x: c.ei_x_buff = std.mem.zeroes(c.ei_x_buff);

    var buff = try std.testing.allocator.alloc(u8, map4.len);
    defer std.testing.allocator.free(buff);

    std.mem.copy(u8, buff, map4);

    x.buff = @ptrCast([*c]u8, buff);

    var term = try EI.Term.init(std.testing.allocator, &x);
    defer term.deinit();
    var value = term.value.map.get(EI.TermValue{.atom = &[_]u8{'a'}});
    try std.testing.expect(value.?.integer == 100);
}

const map5 = @embedFile("term_fixtures/map5.term");

test "decode map5" {
    try EI.init();
    var x: c.ei_x_buff = std.mem.zeroes(c.ei_x_buff);

    var buff = try std.testing.allocator.alloc(u8, map5.len);
    defer std.testing.allocator.free(buff);

    std.mem.copy(u8, buff, map5);

    x.buff = @ptrCast([*c]u8, buff);

    var term = try EI.Term.init(std.testing.allocator, &x);
    defer term.deinit();
    var value = term.value.map.get(EI.TermValue{.atom = &[_]u8{'a'}});
    try std.testing.expect(value.?.integer == 100);

    value = term.value.map.get(EI.TermValue{.atom = &[_]u8{'b'}});
    try std.testing.expectFmt("hello, world", "{s}", .{value.?.binary});
}

const list1 = @embedFile("term_fixtures/list1.term");

test "decode list1" {
    try EI.init();
    var x: c.ei_x_buff = std.mem.zeroes(c.ei_x_buff);

    var buff = try std.testing.allocator.alloc(u8, list1.len);
    defer std.testing.allocator.free(buff);

    std.mem.copy(u8, buff, list1);

    x.buff = @ptrCast([*c]u8, buff);

    var term = try EI.Term.init(std.testing.allocator, &x);
    defer term.deinit();
    try std.testing.expectFmt("a", "{s}", .{term.value.list.items[0].atom});
    try std.testing.expectFmt("b", "{s}", .{term.value.list.items[1].atom});
    try std.testing.expectFmt("c", "{s}", .{term.value.list.items[2].atom});
}

const list2 = @embedFile("term_fixtures/list2.term");

test "decode list2" {
    try EI.init();
    var x: c.ei_x_buff = std.mem.zeroes(c.ei_x_buff);

    var buff = try std.testing.allocator.alloc(u8, list2.len);
    defer std.testing.allocator.free(buff);

    std.mem.copy(u8, buff, list2);

    x.buff = @ptrCast([*c]u8, buff);

    var term = try EI.Term.init(std.testing.allocator, &x);
    defer term.deinit();
    try std.testing.expectFmt("hello", "{s}", .{term.value.list.items[0].binary});
    try std.testing.expectFmt("world", "{s}", .{term.value.list.items[1].string});
}

const list3 = @embedFile("term_fixtures/list3.term");

test "decode list3" {
    try EI.init();
    var x: c.ei_x_buff = std.mem.zeroes(c.ei_x_buff);

    var buff = try std.testing.allocator.alloc(u8, list3.len);
    defer std.testing.allocator.free(buff);

    std.mem.copy(u8, buff, list3);

    x.buff = @ptrCast([*c]u8, buff);

    var term = try EI.Term.init(std.testing.allocator, &x);
    defer term.deinit();
    // [%{a: :b}, %{c: :d}]

    var map_1_value = term.value.list.items[0].map.get(EI.TermValue{.atom = &[_]u8{'a'}});
    try std.testing.expectFmt("b", "{s}", .{map_1_value.?.atom});

    var map_2_value = term.value.list.items[1].map.get(EI.TermValue{.atom = &[_]u8{'c'}});
    try std.testing.expectFmt("d", "{s}", .{map_2_value.?.atom});
}

// const weird_map1 = @embedFile("term_fixtures/weird_map1.term");
// test "decode weird_map1" {
//     try EI.init();
//     var x: c.ei_x_buff = std.mem.zeroes(c.ei_x_buff);

//     var buff = try std.testing.allocator.alloc(u8, weird_map1.len);
//     defer std.testing.allocator.free(buff);

//     std.mem.copy(u8, buff, weird_map1);

//     x.buff = @ptrCast([*c]u8, buff);

//     var term = try EI.Term.init(std.testing.allocator, &x);
//     defer term.deinit();
//     // TODO: %{make_ref() => 123}
// }
