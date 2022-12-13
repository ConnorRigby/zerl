const std = @import("std");

const c = @import("c.zig");

const TermValue = @import("term.zig").TermValue;
const ErlConnect = @import("erl_connect.zig").ErlConnect;
  
pub const Interface = struct {
  ptr: *anyopaque,
  receiveFn: *const fn(*anyopaque, *ErlConnect, *c.erlang_pid, *TermValue) void,
};

pub const Process = struct {
  impl: Interface,
  // pid: c.erlang_pid,

  pub fn init(interface: Interface) Process {
    return .{.impl = interface};
  }
  pub fn deinit(self: *const Process) void {
    _ = self;
  }

  pub fn receive(self: *const Process, conn: *ErlConnect, from: *c.erlang_pid, message: *TermValue) void {
    self.impl.receiveFn(self.impl.ptr, conn, from, message);
  }
};
