const std = @import("std");
const print = std.debug.print;

const ziggycord = @import("ziggycord");

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

    var http = try ziggycord.ZiggycordHttpClient.init(allocator, token);
    defer http.deinit();

    print("going to try it now", .{});

    const start = std.time.microTimestamp();
    try http.getSelf();
    print("queried in {d}μs\n", .{std.time.microTimestamp() - start});
}
