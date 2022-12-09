const std = @import("std");

const c = @cImport({
    @cInclude("ei.h");
    @cInclude("arpa/inet.h");
});


pub const Node = struct {
    pub const InitError = error {
        Xinit,
    };

    pub const ListenError = error {
        Xlisten,
        Publish,
    };

    pub const AcceptError = error {
        ERL_ERROR
    };

    ec: c.ei_cnode,
    addr: c.in_addr,
    port: ?c_int,
    listen_fd: ?c_int,
    accept_fd: ?c_int,
    publish: ?c_int,
    allocator: std.mem.Allocator,


    pub fn init(
        hostname: [:0]const u8, 
        alivename: [:0]const u8, 
        nodename: [:0]const u8,
        cookie: [:0]const u8,
        allocator: std.mem.Allocator,
    ) InitError!Node {

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
        if(xinit < 0) return InitError.Xinit;

        return .{
            .allocator = allocator,
            .ec = ec,
            .addr = addr,
            .port = null,
            .listen_fd = null,
            .publish = null
        };
    }

    pub fn deinit(self: *Node) void {
        if(self.publish) |publish| {
            std.os.close(publish);
        }
        if(self.listen_fd) |listen_fd| {
            std.os.close(listen_fd);
        }
        if(self.accept_fd) |accept_fd| {
            _ = c.ei_close_connection(accept_fd);
        }
    }

    pub fn listen(self: *Node) ListenError!void {
        var port: c_int = undefined;
        const listen_fd = c.ei_xlisten(&self.ec, &self.addr, &port, 10);
        errdefer if(listen_fd > 0) std.os.close(listen_fd);

        if(listen_fd < 0) return ListenError.Xlisten;
        
        const publish = c.ei_publish(&self.ec, port);
        errdefer if(publish > 0) std.os.close(publish);

        if(publish < 0) return ListenError.Publish;
        
        self.port = port;
        self.listen_fd = listen_fd;
        self.publish = publish;
    }

    pub fn accept(self: *Node, timeout: u32) AcceptError!*c.ErlConnect {
        var conn: *c.ErlConnect = self.allocator.alloc(c.ErlConnect, 1);
        errdefer self.allocator.free(conn);

        var conn: c.ErlConnect = undefined;
        const accept_fd = ei_accept_tmo(&self.ec, self.listen_fd, &conn, timeout);
        errdefer if(accept_fd > 0) _ = c.ei_close_connection(accept_fd);
        if(accept_fd < 0) return AcceptError.ERL_ERROR;
        self.accept_fd = accept_fd;

        return &conn;
    }

    pub fn close(self: *Node, conn: *c.ErlConnect) void {
        _ = c.ei_close_connection(accept_fd);
        self.allocator.free(conn);
    }
}; 

pub fn main() !void {
    _ = c.ei_init();

    var node = try Node.init(
        "127.0.0.1", 
        "zig", 
        "zig@127.0.0.1",
        "SECRET_COOKIE",
        std.heap.page_allocator
    );
    defer node.deinit();

    try node.listen();

    _ node.accept(5000);

    while(true) {}
}
