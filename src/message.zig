const std = @import("std.zig");
const c = @import("c.zig");

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
  toname: []const u8,
  msg: c.erlang_msg,
  pub fn init(msg: c.erlang_msg) !Message {
    const toname_len = std.mem.indexOfSentinel(u8, 0, @ptrCast([*:0]const u8, &msg.toname));

    return .{ 
        .message_type = @intToEnum(MessageType, msg.msgtype), 
        .toname = msg.toname[0..toname_len], 
        .msg = msg
    };
  }
};
