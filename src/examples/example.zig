const std = @import("std");
const Allocator = std.mem.Allocator;
const log = std.log;
const helpers = @import("helpers.zig");

const ziggycord = @import("ziggycord");
const HttpClient = ziggycord.http.HttpClient;
const GatewayClient = ziggycord.gateway.GatewayClient;

pub const std_options = struct {
    pub const log_level = .debug;
    pub const logFn = helpers.coloredLogFn;
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
    defer gateway_client.deinit();
    try gateway_client.connect();
}
