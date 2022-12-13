const std = @import("std.zig");
const TermValue = @import("term.zig").TermValue;

pub const GenServer = struct {
    pub const Impl = struct {
        ptr: *anyopaque,
        handle_castFn: *const fn(*anyopaque, *const TermValue) void,
        handle_callFn: *const fn(*anyopaque, *const TermValue, *const TermValue) TermValue,
    };
    node: *Node,
    impl: Impl,

    pub fn receive(ptr: *anyopaque, conn: *const ErlConnect, from: *c.erlang_pid, message: *const TermValue) void {
        _ = from;
        const self = @ptrCast(*GenServer, @alignCast(@alignOf(GenServer), ptr));
        switch(message.*) {
            .tuple => {
                switch(message.tuple[0]) {
                    .atom => {
                        if(std.mem.eql(u8, "$gen_cast", message.tuple[0].atom)) {
                            std.debug.assert(message.tuple.len == 2);
                            self.impl.handle_castFn(self.impl.ptr, &message.tuple[1]);
                        } else if(std.mem.eql(u8, "$gen_call", message.tuple[0].atom)) {
                            std.debug.assert(message.tuple.len == 3);
                            // TODO: sanity check the  gen server message structure 
                            var from_pid = message.tuple[1].tuple[0].pid;
                            const tag = message.tuple[1].tuple[1].list;

                            const result = self.impl.handle_callFn(self.impl.ptr, &message.tuple[1], &message.tuple[2]);
                            _ = c.ei_send(conn.fd, &from_pid, result_buff.buff, result_buff.index);

                        } else {
                            std.debug.print("message: {s}\n", .{message.tuple[0].atom});
                            @panic("unexpected genserver message");
                        }
                    },
                    else =>  @panic("TODO: forward message to impl"),
                }
            },
            else => @panic("TODO: forward message to impl"),
        }
    }
};