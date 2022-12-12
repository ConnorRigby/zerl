const std = @import("std");

const c = @import("c.zig");

const TermValue = @import("ei.zig").TermValue;
const ErlConnect = @import("erl_connect.zig").ErlConnect;
  
pub const Process = struct {
  pub const Interface = struct {
    ptr: *anyopaque,
    receiveFn: *const fn(*anyopaque, *ErlConnect, *c.erlang_pid, *TermValue) void,
  };

  impl: Interface,
  // pid: c.erlang_pid,

  pub fn init(interface: Interface) Process {
    return .{.impl = interface};
  }

  pub fn receive(self: *const Process, conn: *ErlConnect, from: *c.erlang_pid, message: *TermValue) void {
    self.impl.receiveFn(self.impl.ptr, conn, from, message);
  }
};
