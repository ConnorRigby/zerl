const std = @import("std");
const c = @import("c.zig");

const ErlError = @import("erl_error.zig").ErlError;
const _erl_connect = @import("erl_connect.zig");
const ErlConnect = _erl_connect.ErlConnect;
const ErlConnectReceive = _erl_connect.Receive;

const EI = @import("ei.zig");

const _process = @import("process.zig");
pub const Process = _process.Process;
pub const ProcessContext = _process.Context;

// Root level struct that handles a single
// Erlang Distribution Node. You will most likely
// only have one instance of this strucct
pub const Node = struct {
    allocator: std.mem.Allocator,
    ec: c.ei_cnode,
    addr: c.in_addr,
    nodename: []u8,

    port: ?c_int,
    listen_fd: ?c_int,
    publish: ?c_int,
    creation: u32,

    // K=atom V=Process
    // TODO: how to have an array of generics like this?
    processes: std.HashMap([]const u8, Process, ProcessContext, 80),

    pub fn init(
        hostname: [:0]const u8,
        alivename: [:0]const u8,
        nodename: [:0]const u8,
        cookie: [:0]const u8,
        creation: u32,
        allocator: std.mem.Allocator, // TODO: reorder args, i think allocator should be first
    ) !Node {
        // TODO: maybe this address should be configurable?
        // I think one may want to use 0.0.0.0
        var addr: c.in_addr = undefined;
        addr.s_addr = c.inet_addr("127.0.0.1");

        var ec: c.ei_cnode = undefined;
        const xinit = c.ei_connect_xinit(&ec, hostname.ptr, alivename.ptr, nodename.ptr, &addr, cookie.ptr, creation);
        if (xinit < 0) return ErlError.ei_connect_xinit;

        var thisnodename_ = c.ei_thisnodename(&ec);
        const nodename_ = std.mem.span(thisnodename_);
        var thisnodename = try allocator.alloc(u8, nodename_.len);
        std.mem.copy(u8, thisnodename, nodename_);

        const processes = std.HashMap(
            []const u8, 
            Process, 
            ProcessContext, 
            80
        ).init(allocator);
        errdefer processes.deinit();

        return .{ .allocator = allocator, 
        .processes = processes,
        .creation = creation, .ec = ec, .addr = addr, .nodename = thisnodename, .port = null, .listen_fd = null, .publish = null };
    }

    pub fn deinit(self: *Node) void {
        if (self.publish) |publish| std.os.close(publish);
        if (self.listen_fd) |listen_fd| std.os.close(listen_fd);
        self.allocator.free(self.nodename);
        // TODO: deinit each process
        self.processes.deinit();
    }

    // Open a listen socket. Non blocking. 
    pub fn listen(self: *Node) !void {
        var port: c_int = undefined;
        const listen_fd = c.ei_xlisten(&self.ec, &self.addr, &port, 10);
        errdefer if (listen_fd > 0) std.os.close(listen_fd);

        if (listen_fd < 0) return ErlError.ei_xlisten;

        const publish = c.ei_publish(&self.ec, port);
        errdefer if (publish > 0) std.os.close(publish);

        if (publish < 0) return ErlError.ei_publish;

        self.port = port;
        self.listen_fd = listen_fd;
        self.publish = publish;
    }

    // Accept one new connection. Returns the connection
    // or an Error if no connection happens in `timeout` ms
    pub fn accept(self: *Node, timeout: u32) !ErlConnect {
        var conn: *c.ErlConnect = try self.allocator.create(c.ErlConnect);
        errdefer self.allocator.destroy(conn);

        // unfortunately ei doesn't set this value to 0
        std.mem.set(u8, &conn.nodename, 0);

        const accept_fd = c.ei_accept_tmo(&self.ec, self.listen_fd.?, conn, timeout);
        errdefer if (accept_fd > 0) {_ = c.ei_close_connection(accept_fd);};

        if (accept_fd < 0) return ErlError.ei_accept;
        return ErlConnect.init(self.allocator, conn, accept_fd);
    }

    // Close a accepted connection
    // deinits the entire connection and all the memory
    // allocated with it
    // TODO maybe this functions shouldn't exist,
    // the entire thing could be on the `conn` struct.
    pub fn close(self: *Node, conn: *ErlConnect) void {
        _ = self;
      conn.deinit();
    }

    // process an incoming message from another connection
    pub fn handle_message(self: *Node, conn: *const ErlConnect, msg: *const ErlConnectReceive) !void {
        switch(msg.message_type) {
            .RegSend => try reg_send(self, conn, msg),
            else => |t| {
                std.debug.print("unhandled message: {any}\n", .{t});
                @panic("unhandled message");
            }
        }
    }

    // handle .RegSend
    fn reg_send(self: *Node, conn: *const ErlConnect, msg: *const ErlConnectReceive) !void {
        _ = self; _ = conn; _ = msg;
        @panic("reg_send not implemented");
    }
};
