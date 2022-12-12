const std = @import("std");

const erl_include_dir = "/home/connor/.asdf/installs/erlang/25.1.2/usr/include/";
const erts_include_dir = "/home/connor/.asdf/installs/erlang/25.1.2/erts-13.1.2/include/";

const erl_lib_dir = "/home/connor/.asdf/installs/erlang/25.1.2/usr/lib/";

pub fn build(b: *std.build.Builder) void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard release options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall.
    const mode = b.standardReleaseOptions();

    const exe = b.addExecutable("zerl", "src/main.zig");
    exe.setTarget(target);
    exe.setBuildMode(mode);
    exe.addIncludePath(erl_include_dir);
    exe.addIncludePath(erts_include_dir);
    exe.addLibraryPath(erl_lib_dir);
    // exe.linkSystemLibrary("ei");
    exe.linkSystemLibrary("ei_st");
    exe.linkLibC();
    exe.install();

    const run_cmd = exe.run();
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const exe_tests = b.addTest("src/main.zig");
    exe_tests.addIncludePath(erl_include_dir);
    exe_tests.addIncludePath(erts_include_dir);
    exe_tests.addLibraryPath(erl_lib_dir);
    // exe_tests.linkSystemLibrary("ei");
    exe_tests.linkSystemLibrary("ei_st");
    exe_tests.setTarget(target);
    exe_tests.setBuildMode(mode);
    exe_tests.linkLibC();

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&exe_tests.step);
}
