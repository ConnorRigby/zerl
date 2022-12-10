const std = @import("std");
const c = @import("c.zig");

const ErlError = @import("erl_error.zig").ErlError;
const ErlConnect = @import("erl_connect.zig").ErlConnect;

pub const Node = struct {
    allocator: std.mem.Allocator,
    ec: c.ei_cnode,
    addr: c.in_addr,
    nodename: []u8,
    
    port: ?c_int,
    listen_fd: ?c_int,
    publish: ?c_int,

    pub fn init(
        hostname: [:0]const u8, 
        alivename: [:0]const u8, 
        nodename: [:0]const u8,
        cookie: [:0]const u8,
        allocator: std.mem.Allocator,
    ) !Node {
        var addr: c.in_addr = undefined;
        addr.s_addr = c.inet_addr("127.0.0.1");
        const creation: c_int = 1;

        var ec: c.ei_cnode = undefined;
        const xinit = c.ei_connect_xinit(
            &ec, 
            hostname.ptr, 
            alivename.ptr, 
            nodename.ptr, 
            &addr, 
            cookie.ptr, 
            creation
        );
        if(xinit < 0) return ErlError.ei_connect_xinit;

        var thisnodename_ = c.ei_thisnodename(&ec);
        const nodename_ = std.mem.span(thisnodename_);
        var thisnodename = try allocator.alloc(u8, nodename_.len);
        std.mem.copy(u8, thisnodename, nodename_);

        return .{
            .allocator = allocator,
            .ec = ec,
            .addr = addr,
            .nodename = thisnodename,
            .port = null,
            .listen_fd = null,
            .publish = null
        };
    }

    pub fn deinit(self: *Node) void {
        if(self.publish) |publish| std.os.close(publish);
        if(self.listen_fd) |listen_fd| std.os.close(listen_fd);
        self.allocator.free(self.nodename);
    }

    pub fn listen(self: *Node) !void {
        var port: c_int = undefined;
        const listen_fd = c.ei_xlisten(&self.ec, &self.addr, &port, 10);
        errdefer if(listen_fd > 0) std.os.close(listen_fd);

        if(listen_fd < 0) return ErlError.ei_xlisten;
        
        const publish = c.ei_publish(&self.ec, port);
        errdefer if(publish > 0) std.os.close(publish);

        if(publish < 0) return ErlError.ei_publish;
        
        self.port = port;
        self.listen_fd = listen_fd;
        self.publish = publish;
    }

    pub fn accept(self: *Node, timeout: u32) !ErlConnect {
        var conn: *c.ErlConnect = try self.allocator.create(c.ErlConnect);
        errdefer self.allocator.destroy(conn);

        // unfortunately ei doesn't set this value to 0
        std.mem.set(u8, &conn.nodename, 0);

        const accept_fd = c.ei_accept_tmo(&self.ec, self.listen_fd.?, conn, timeout);
        errdefer if(accept_fd > 0) {_ = c.ei_close_connection(accept_fd);};

        if(accept_fd < 0) return ErlError.ei_accept;

        const nodename_ = std.mem.span(&conn.nodename);

        var nodename: [:0]u8 = try self.allocator.allocSentinel(u8, nodename_.len, 0);
        errdefer self.allocator.free(nodename);

        std.mem.set(u8, nodename, 0);
        std.mem.copy(u8, nodename, nodename_);

        return .{.conn = conn, .fd = accept_fd, .nodename = nodename};
    }

    pub fn close(self: *Node, conn: ErlConnect) void {
        _ = c.ei_close_connection(conn.fd);
        self.allocator.destroy(conn.conn);
        self.allocator.free(conn.nodename);
    }
};
