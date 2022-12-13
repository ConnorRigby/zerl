const std = @import("std");

const TermValue = @import("term.zig").TermValue;

pub const NetKernel = struct {
 pub fn handle_cast(ptr: *anyopaque, message: *const TermValue) void {
  _ = ptr;
  std.debug.print("handling cast: {any}\n", .{message});
 }

 pub fn handle_call(ptr: *anyopaque, call: *const TermValue, from: *const TermValue) TermValue {
  _ = ptr;
  _ = call;
  _ = from;
  return .{ .atom = "yes" };
 }
};
