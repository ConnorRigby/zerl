const std = @import("std");
const c = @import("c.zig");

pub const ErlError = @import("erl_error.zig").ErlError;

// Initialize the EI library
pub fn init() !void {
  if (c.ei_init() != 0) return ErlError.ei_init;
}
