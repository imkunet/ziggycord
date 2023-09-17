const std = @import("std");
const Allocator = std.mem.Allocator;
const log = std.log;

const ziggycord = @import("ziggycord");
const HttpClient = ziggycord.http.HttpClient;

pub fn customLogFn(comptime level: log.Level, comptime scope: @TypeOf(.EnumLiteral), comptime format: []const u8, args: anytype) void {
    const level_txt = comptime level.asText();
    const prefix2 = if (scope == .default) " " else "(" ++ @tagName(scope) ++ "): ";
    const stderr = std.io.getStdErr().writer();
    std.debug.getStderrMutex().lock();
    defer std.debug.getStderrMutex().unlock();
    nosuspend stderr.print(level_txt ++ prefix2 ++ format ++ "\n", args) catch return;
}

pub const std_options = struct {
    pub const log_level = .info;
    pub const logFn = customLogFn;
};

fn getToken(allocator: Allocator) ?[]u8 {
    const token = std.process.getEnvVarOwned(allocator, "DISCORD_TOKEN") catch |err| {
        if (err == std.process.GetEnvVarOwnedError.EnvironmentVariableNotFound) {
            log.err("Please specify the DISCORD_TOKEN environment variable\n", .{});
            return null;
        }

        log.err("Something went really wrong here: {any}\n", .{err});
        return null;
    };

    return token;
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    const token = getToken(allocator) orelse return;
    defer allocator.free(token);

    var http = try HttpClient.init(allocator, token);
    defer http.deinit();

    log.info("going to try it now\n", .{});

    const start = std.time.microTimestamp();

    const user = try http.getSelf();
    defer user.deinit();
    log.info("my user id: {s}", .{user.value.id});

    log.info("queried in {d}μs\n", .{std.time.microTimestamp() - start});
}
