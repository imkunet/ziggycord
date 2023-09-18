const std = @import("std");
const Allocator = std.mem.Allocator;
const log = std.log;

const ziggycord = @import("ziggycord");
const HttpClient = ziggycord.http.HttpClient;
const GatewayClient = ziggycord.gateway.GatewayClient;

const ESC = "\x1b[";
const RESET = ESC ++ "0m";

inline fn esc(comptime inside: []const u8) []const u8 {
    return ESC ++ inside ++ "m";
}

fn levelText(comptime level: log.Level) []const u8 {
    return switch (level) {
        .err => esc("31") ++ "FATL",
        .warn => esc("33") ++ "WARN",
        .info => esc("34") ++ "INFO",
        .debug => esc("32") ++ "DBUG",
    };
}

pub fn coloredLogFn(comptime level: log.Level, comptime scope: @TypeOf(.EnumLiteral), comptime format: []const u8, args: anytype) void {
    const level_text = comptime levelText(level);
    const scope_text = if (scope == .default) " " else "(" ++ @tagName(scope) ++ "): ";

    const stderr = std.io.getStdErr().writer();
    std.debug.getStderrMutex().lock();
    defer std.debug.getStderrMutex().unlock();

    nosuspend stderr.print(level_text ++ RESET ++ scope_text ++ format ++ "\n", args) catch return;
}

pub const std_options = struct {
    pub const log_level = .debug;
    pub const logFn = coloredLogFn;
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

    log.info("going to try it now", .{});

    const start = std.time.milliTimestamp();

    const user = try http.getSelf();
    defer user.deinit();
    log.info("my user id: {s}", .{user.value.id});

    log.info("queried in {d}ms", .{std.time.milliTimestamp() - start});

    const gateway_info = try http.getGatewayBot();
    defer gateway_info.deinit();

    log.info("websocket url {s}", .{gateway_info.value.url});

    var gateway_client = try GatewayClient.init(allocator, http);
    try gateway_client.connect();

    // sleep so we can check memory usage of the process
    std.time.sleep(std.time.ns_per_s * 5);
}
