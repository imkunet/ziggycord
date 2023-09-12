const std = @import("std");
const print = std.debug.print;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    const token = std.process.getEnvVarOwned(allocator, "DISCORD_TOKEN") catch |err| {
        if (err == std.process.GetEnvVarOwnedError.EnvironmentVariableNotFound) {
            print("Please specify the DISCORD_TOKEN environment variable\n", .{});
            return;
        }

        print("Something went really wrong here: {any}\n", .{err});
        return;
    };

    print("hello world! {s}\n", .{token});
}
