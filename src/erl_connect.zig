const std = @import("std");
const c = @import("c.zig");

const ErlError = @import("erl_error.zig").ErlError;
const EI = @import("ei.zig");

// structure containing a single control message
// and term from another connection
pub const Receive = struct {
    message: EI.Message,
    term: EI.Term,

    pub fn init(allocator: std.mem.Allocator, emsg: c.erlang_msg, x: *c.ei_x_buff) !Receive {
        return .{ .message = try EI.Message.init(emsg), .term = try EI.Term.init(allocator, x) };
    }

    pub fn deinit(self: *Receive) void {
        // self.message.deinit();
        self.term.deinit();
    }
};

pub const ErlConnect = struct {
    allocator: std.mem.Allocator,
    conn: *c.ErlConnect, // connection as from the `accept` function
    fd: c_int,           // socket that can be receive'd on
    nodename: [:0]u8,    // current node's name
    x: c.ei_x_buff,      // buffer for holding term value

    pub fn init(allocator: std.mem.Allocator, conn: *c.ErlConnect, fd: c_int) !ErlConnect {
        // long winded way of creating a copy of the nodename string
        const nodename_ = std.mem.span(&conn.nodename);
        var nodename: [:0]u8 = try allocator.allocSentinel(u8, nodename_.len, 0);
        errdefer allocator.free(nodename);

        std.mem.set(u8, nodename, 0);
        std.mem.copy(u8, nodename, nodename_);

        // buffer for storing terms
        var x = std.mem.zeroes(c.ei_x_buff);
        errdefer {_ = c.ei_x_free(&x);}

        // initialize the buffer before receiving
        _ = c.ei_x_new(&x); // todo: check for out of memory

        return .{.allocator = allocator, .conn = conn, .nodename = nodename, .x = x, .fd = fd};
    }

    pub fn deinit(self: *ErlConnect) void {
      _ = c.ei_close_connection(self.fd);
      _ = c.ei_x_free(&self.x);
      self.allocator.destroy(self.conn);
      self.allocator.free(self.nodename);
    }

    pub fn receive(self: *ErlConnect, timeout: usize) !Receive {
        // control message
        var emsg: c.erlang_msg = std.mem.zeroes(c.erlang_msg);

        switch (c.ei_xreceive_msg_tmo(self.fd, &emsg, &self.x, @intCast(c_uint, timeout))) {
            c.ERL_TICK => return ErlError.TICK,
            c.ERL_ERROR => {
                if (c.__erl_errno == c.ETIMEDOUT) return ErlError.TIMEOUT;
                if (c.__erl_errno == c.EIO) return ErlError.EIO;

                std.debug.print("\n\nunknown error: {d}\n\n", .{c.__erl_errno});
                return ErlError.ERROR;
            },
            else => {
                // handles receiving the entire term payload
                self.x.index = 0; // ????
                return Receive.init(self.allocator, emsg, &self.x);
            },
        }
    }
};
