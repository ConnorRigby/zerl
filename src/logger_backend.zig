const std = @import("std");

const TermValue = @import("term.zig").TermValue;

pub const LoggerBackend = struct {
  pub fn handle_cast(ptr: *anyopaque, message: *const TermValue) void {
    _ = ptr;
    var level = message.tuple[0].atom;
    // var pid = message.tuple[1];
    var log = message.tuple[2].tuple;
    var module  = log[0].atom;
    var content = log[1].binary;
    if(std.mem.eql(u8, "info", level)) {
      std.log.info("{s}: {s}", .{module, content});
    } else {
      std.debug.print("unknown log type: {s}\n", .{level});
    }
  }

  pub fn handle_call(ptr: *anyopaque, call: *const TermValue, from: *const TermValue) TermValue {
    _ = ptr;
    _ = call;
    _ = from;
    return .{ .atom = "ok" };
  }
};
