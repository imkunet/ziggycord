const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const ziggycord = b.addModule("ziggycord", .{
        .source_file = .{ .path = "src/ziggycord/ziggycord.zig" },
    });

    const ws = b.dependency("websocket_zig", .{
        .target = target,
        .optimize = optimize,
    }).module("websocket");

    // test bot

    const test_exe = b.addExecutable(.{
        .name = "test_bot",
        .root_source_file = .{ .path = "src/examples/example.zig" },
        .target = target,
        .optimize = optimize,
    });
    //test_exe.strip = true;
    test_exe.addModule("websocket", ws);
    test_exe.addModule("ziggycord", ziggycord);

    const install_example = b.addInstallArtifact(test_exe, .{});

    const example_step = b.step("example", "Builds and installs the example bot");
    example_step.dependOn(&test_exe.step);
    example_step.dependOn(&install_example.step);

    // tests (broken not sure why yet)

    const tests = b.addTest(.{
        .root_source_file = std.build.FileSource.relative("src/ziggycord/ziggycord.zig"),
        .target = target,
        .optimize = optimize,
    });
    tests.addModule("websocket", ws);
    tests.addModule("ziggycord", ziggycord);

    const tests_step = b.step("test", "Run the tests");
    tests_step.dependOn(&tests.step);

    // autodocs

    const autodoc_test = b.addTest(.{
        .root_source_file = std.Build.FileSource.relative("src/ziggycord/ziggycord.zig"),
        .target = target,
        .optimize = optimize,
    });
    autodoc_test.addModule("websocket", ws);
    autodoc_test.addModule("ziggycord", ziggycord);

    const install_docs = b.addInstallDirectory(.{
        .source_dir = autodoc_test.getEmittedDocs(),
        .install_dir = .prefix,
        .install_subdir = "docs",
    });

    const docs_step = b.step("docs", "Builds and installs the documentation");
    docs_step.dependOn(&install_docs.step);
}
