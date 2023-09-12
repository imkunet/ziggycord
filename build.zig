const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{
        //.preferred_optimize_mode = .ReleaseFast,
    });

    const ziggycord = b.addModule("ziggycord", .{
        .source_file = .{ .path = "src/ziggycord/ziggycord.zig" },
    });

    const ws = b.dependency("websocket_zig", .{
        .target = target,
        .optimize = optimize,
    });

    const test_exe = b.addExecutable(.{
        .name = "test_bot",
        .root_source_file = .{ .path = "src/examples/example.zig" },
        .target = target,
        .optimize = optimize,
    });

    test_exe.addModule("websocket", ws.module("websocket"));
    test_exe.addModule("ziggycord", ziggycord);

    b.installArtifact(test_exe);
}
