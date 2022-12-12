const std = @import("std");

pub fn Process(comptime T: type) type {
  return struct {
    pub fn init() T {
      return .{};
    }
  };
}

// pub const process = struct {
//   allocator: std.mem.Allocator,

//   pub const init(allocator: std.mem.Allocator) !Process {

//     return .{.allocator = allocator};
//   }
// };

// HashMap implementation
pub const Context = struct {
    pub fn hash(context: Context, key: []const u8) u64 {
        _ = context; _ = key;
        @panic("not implemented");
    }
    pub fn eql(context: Context, a: []const u8, b: []const u8) bool {
        _ = context; _ = a; _ = b;
        @panic("not implemented");
    }
};