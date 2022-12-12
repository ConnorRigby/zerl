const std = @import("std");
const c = @import("c.zig");

pub const ErlError = @import("erl_error.zig").ErlError;
pub const DecodeError = std.mem.Allocator.Error || ErlError;

// Initialize the EI library
pub fn init() !void {
    if (c.ei_init() != 0) return ErlError.ei_init;
}

pub const TermType = enum(c_int) { 
    Atom = c.ERL_ATOM_EXT, 
    Binary = c.ERL_BINARY_EXT, 
    BitBinary = c.ERL_BIT_BINARY_EXT, 
    Float = c.ERL_FLOAT_EXT, 
    NewFun = c.ERL_NEW_FUN_EXT, 
    Fun = c.ERL_FUN_EXT, 
    ExPort = c.ERL_EXPORT_EXT, 
    SmallInteger = c.ERL_SMALL_INTEGER_EXT, 
    Integer = c.ERL_INTEGER_EXT, 
    SmallBig = c.ERL_SMALL_BIG_EXT, 
    LargeBig = c.ERL_LARGE_BIG_EXT, 
    List = c.ERL_LIST_EXT, 
    Nil = c.ERL_NIL_EXT, 
    String = c.ERL_STRING_EXT, 
    Map = c.ERL_MAP_EXT, 
    Pid = c.ERL_PID_EXT, 
    Port = c.ERL_PORT_EXT, 
    NewReference = c.ERL_NEW_REFERENCE_EXT, 
    SmallTuple = c.ERL_SMALL_TUPLE_EXT, 
    LargeTuple = c.ERL_LARGE_TUPLE_EXT 
};

pub const TermContext = struct {
    // TODO: this function will currently cause duplicated
    // keys due to the lazy hashing. 
    // for example, %{20.0 => :abc} and %{20 => :abc} are treated as
    // the same map at the moment
    // This gets even weirder with compound type keys such as tuples
    // lists or even more maps.
    pub fn hash(context: TermContext, key: TermValue) u64 {
        _ = context;
        const v = switch(key) {
            .integer => @intCast(u64, key.integer),
            .double => @floatToInt(u64, key.double),
            .atom => std.hash.Crc32.hash(key.atom),
            // .pid => std.hash.Crc32.hash(std.mem.asBytes(&key.pid)),
            // .port => std.hash.Crc32.hash(std.mem.asBytes(&key.port)),
            .ref => std.hash.Crc32.hash(std.mem.asBytes(&key.ref.n)),
            // .binary => std.hash.Crc32.hash(std.mem.asBytes(&key.binary)),
            // .string => std.hash.Crc32.hash(std.mem.asBytes(&key.string)),
            else => @panic("unknown type for map storage"),
        };
        std.debug.print("key={any}={any}\n", .{key, v});
        return v;
    }
    // this function should match the internal
    // implementation in Erlang, but i didn't look it up,
    // so it's implemented mostly by gut feeling at the moment
    pub fn eql(context: TermContext, a: TermValue, b: TermValue) bool {
        _ = context;
        // differnt types shouldn't be compared?
        if(@as(TermValueType, a) != @as(TermValueType, b)) return false;

        return switch(a) {
            .integer => a.integer == b.integer,
            .double => a.double == b.double,
            .atom => {
                if(a.atom.len != b.atom.len) return false;
                var i:usize = 0;
                while(i < 0):(i = i+1){
                    if(a.atom[i] != b.atom[i]) return false;
                }
                // if every character matched, the atoms must match
                return true;
            },
            else => @panic("type comparision not implemented for this type")
        };
    }
};

pub const TermValueType = enum { 
    integer, 
    double, 
    pid, 
    port, 
    ref, 
    atom,
    binary,
    string,
    tuple,
    map,
    list
};

pub const TermValue = union(TermValueType) { 
    integer: isize, 
    double: f64, 
    pid: c.erlang_pid, 
    port: c.erlang_port, 
    ref: c.erlang_ref, 
    atom: []const u8, 
    binary: []const u8,
    string: []const u8,
    tuple: []TermValue,
    map: std.HashMap(TermValue, TermValue, TermContext, 80),
    list: std.ArrayList(TermValue)
};

pub const Term = struct {
    allocator: std.mem.Allocator,
    term_type: TermType,
    value: TermValue,
    arity: i32,
    size: i32,

    pub fn decode(allocator: std.mem.Allocator, x: *const c.ei_x_buff, index: *c_int) DecodeError!Term {
        var term: c.ei_term = std.mem.zeroes(c.ei_term);
        const t = c.ei_decode_ei_term(x.buff, index, &term);
        if (t == -1) return ErlError.ei_decode_ei_term;
        const value = try decode_value(allocator, x, &term, index);
        return .{ .allocator = allocator, .term_type = @intToEnum(TermType, term.ei_type), .arity = @intCast(i32, term.arity), .size = @intCast(i32, term.size), .value = value };
    }

    pub fn decode2(allocator: std.mem.Allocator, x: *const c.ei_x_buff, index: *c_int) DecodeError!TermValue {
        std.debug.print("index={d}\n", .{index.*});
        var term: c.ei_term = std.mem.zeroes(c.ei_term);
        const t = c.ei_decode_ei_term(x.buff, index, &term);
        if (t == -1) return ErlError.ei_decode_ei_term;
        return decode_value(allocator, x, &term, index);
    }

    fn decode_value(allocator: std.mem.Allocator, x: *const c.ei_x_buff, term: *c.ei_term, index: *c_int) !TermValue {
        std.debug.print("type={s} size={d} arity={d}\n", .{@tagName(@intToEnum(TermType, term.ei_type)), term.size, term.arity});
        switch (@intToEnum(TermType, term.ei_type)) {
            .SmallInteger, .Integer => return TermValue{ .integer = @intCast(isize, term.value.i_val) },
            .SmallBig, .LargeBig, .Float => return TermValue{ .double = term.value.d_val },
            .Pid => return TermValue{ .pid = term.value.pid },
            .NewReference => return TermValue{ .ref = term.value.ref },
            .Atom =>  {
                const len = std.mem.indexOfSentinel(u8, 0, @ptrCast([*:0]u8, &term.value.atom_name));
                const atom = try allocator.alloc(u8, len);
                errdefer allocator.free(atom);
                std.mem.set(u8, atom, 0);
                std.mem.copy(u8, atom, term.value.atom_name[0..len]);
                return TermValue{ .atom = atom };
            },
            .Binary, .String => | t | {
                const binary = try allocator.alloc(u8, @intCast(usize, term.size));
                errdefer allocator.free(binary);
                var len: c_long = 0;
                if(t == .Binary) {
                    const b = c.ei_decode_binary(x.buff, index, binary.ptr, &len);
                    if (b == -1) return ErlError.ei_decode_ei_term;
                    if (len != term.size) {
                        std.debug.print("length doesnt match {d},{d}\n", .{ len, term.size });
                    }
                    return TermValue{ .binary = binary };
                } else if(t == .String) {
                    const b = c.ei_decode_string(x.buff, index, binary.ptr);
                    if (b == -1) return ErlError.ei_decode_ei_term;
                    return TermValue{ .string = binary };
                } else {unreachable;}
            },
            .SmallTuple, .LargeTuple => {
                const tuple = try allocator.alloc(TermValue, @intCast(usize, term.arity));
                errdefer allocator.free(tuple);

                var i: usize = 0;
                while(i < term.arity):(i = i+1) {
                    tuple[i] = try decode2(allocator, x, index);
                }

                return TermValue{ .tuple = tuple };
            },
            .Map => {
                var map = std.HashMap(TermValue, TermValue, TermContext, 80).init(allocator);
                errdefer map.deinit();
                var i: usize = 0;
                while(i < term.arity):(i = i + 1)  {
                    var key = try decode2(allocator, x, index);
                    var value = try decode2(allocator, x, index);
                    try map.put(key, value);
                }
                return TermValue{.map = map};
            },
            .List => {
                // could likely be a standard allocator.alloc(TermValue, term.size)
                // but this gives an easy way to append to the list 
                // for term construction
                var list = try std.ArrayList(TermValue).initCapacity(allocator, @intCast(usize, term.arity));
                errdefer list.deinit();

                var i: usize = 0;
                while(i < term.arity):(i = i + 1) {
                    var item = try decode2(allocator, x, index);
                    try list.append(item);
                }
                return TermValue{.list = list};
            },
            else => @panic("unknown erlang type"),
        }
    }

    pub fn init(allocator: std.mem.Allocator, x: *const c.ei_x_buff) !Term {
        var index: c_int = 0;
        var version: c_int = 0;
        if (c.ei_decode_version(x.buff, &index, &version) == -1) return ErlError.ei_decode_version;
        return decode(allocator, x, &index);
    }

    pub fn deinit(self: *Term) void {
        free_value(self.allocator, &self.value);
    }

    pub fn free_value(allocator: std.mem.Allocator, value: *TermValue) void {
        switch (value.*) {
            .atom => allocator.free(value.atom),
            .binary => allocator.free(value.binary),
            .string => allocator.free(value.string),
            .tuple => {
                var i: usize = 0;
                while(i < value.tuple.len):(i = i + 1) {
                    free_value(allocator, &value.tuple[i]);
                }
                allocator.free(value.tuple);
            },
            .map => {
                var itter = value.map.keyIterator();
                while(itter.next()) |key| {
                    var map_value = value.map.get(key.*);
                    free_value(allocator, &map_value.?);
                    free_value(allocator, key);
                }
                value.map.deinit();
            },
            .list => {
                var list_slice = value.list.toOwnedSlice();
                defer allocator.free(list_slice);
                var i: usize = 0;
                while(i < list_slice.len):(i = i + 1) {
                    free_value(allocator, &list_slice[i]);
                }
                value.list.deinit();
            },
            else => {},
        }
    }
};

pub const MessageType = enum(c_int) { 
    Link = c.ERL_LINK, 
    Send = c.ERL_SEND, 
    Exit = c.ERL_EXIT, 
    Unlink = c.ERL_UNLINK, 
    NodeLink = c.ERL_NODE_LINK, 
    RegSend = c.ERL_REG_SEND, 
    GroupLeader = c.ERL_GROUP_LEADER, 
    Exit2 = c.ERL_EXIT2, 
    PassThrough = c.ERL_PASS_THROUGH 
};

pub const Message = struct {
    message_type: MessageType,
    from: c.erlang_pid,
    to: c.erlang_pid,
    toname: []const u8,
    msg: c.erlang_msg,
    pub fn init(msg: c.erlang_msg) !Message {
        return .{ .message_type = @intToEnum(MessageType, msg.msgtype), .from = msg.from, .to = msg.to, .toname = std.mem.span(&msg.toname), .msg = msg };
    }
};
