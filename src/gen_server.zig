const std = @import("std");

pub const message_t = u8;
pub const from_t = u8;

pub const reply_t = struct { from: ?from_t, data: ?message_t };

pub const noreply: reply_t = .{ .from = null, .data = null };

pub fn GenServer(comptime T: type) type {
    if (!@hasDecl(T, "init")) @panic(@typeName(T) ++ " Does not define an init function");
    if (!@hasDecl(T, "handle_info")) @panic(@typeName(T) ++ " Does not define an handle_info function");
    if (!@hasDecl(T, "handle_call")) @panic(@typeName(T) ++ " Does not define an handle_call function");
    if (!@hasDecl(T, "handle_cast")) @panic(@typeName(T) ++ " Does not define an handle_cast function");

    return struct {
        pub fn init() T {
            return T.init();
        }

        pub fn terminate(state: *T, reason: anyerror) void {
            state.terminate(reason);
        }

        pub fn call(state: *T, message: message_t, from: from_t) reply_t {
            return state.handle_call(message, from);
        }

        pub fn cast(state: *T, message: message_t) void {
            state.handle_cast(message);
        }

        pub fn info(state: *T, message: message_t) void {
            state.handle_info(message);
        }
    };
}

const MyState = struct {
    count: usize,

    pub fn init() MyState {
        return .{ .count = 0 };
    }

    pub fn handle_info(self: *MyState, msg: anytype) void {
        _ = self;
        _ = msg;
    }

    pub fn handle_cast(self: *MyState, msg: anytype) void {
        _ = self;
        _ = msg;
    }

    pub fn handle_call(self: *MyState, msg: message_t, from: from_t) reply_t {
        self.count = msg;
        return .{ .from = from, .data = msg };
    }

    pub fn terminate(self: *MyState, reason: anyerror) void {
        _ = self;
        std.debug.print("state terminate: {s}\n", .{@errorName(reason)});
    }
};

const AllocationError = error{
    OutOfMemory,
};

test "example" {
    const my_server = GenServer(MyState);

    var my_state = my_server.init();
    defer my_server.terminate(&my_state, AllocationError.OutOfMemory);

    var count = my_server.call(&my_state, 1, 2);
    std.debug.print("{any} {?d}\n", .{ my_state, count.data });

    count = my_server.call(&my_state, 2, 2);

    // defer my_server.terminate();
    std.debug.print("{any} {?d}\n", .{ my_state, count.data });
}
