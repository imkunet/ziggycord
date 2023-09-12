const std = @import("std");

const http = std.http;

pub const snowflake = @import("snowflake.zig");
pub const GatewayIntents = @import("intents.zig");

const BASE_URL = "https://discord.com/api/v10";
const VERSION = "0.1.0";
const USER_AGENT = std.fmt.comptimePrint("Ziggycord (https://github.com/imkunet/ziggycord/, v{s})", .{VERSION});

pub const ZiggycordHttpClient = struct {
    allocator: std.mem.Allocator,
    token: []const u8,

    http_client: http.Client,
    http_options: http.Client.Options,
    http_headers: http.Headers,

    pub fn init(allocator: std.mem.Allocator, token: []const u8) !ZiggycordHttpClient {
        var headers = http.Headers.init(allocator);
        try headers.append("Authorization", token);
        try headers.append("User-Agent", USER_AGENT);
        try headers.append("Content-Type", "application/json");
        try headers.append("Accept", "application/json");
        headers.sort();

        return .{
            .allocator = allocator,
            .token = token,
            .http_client = http.Client{
                .allocator = allocator,
            },
            .http_options = http.Client.Options{},
            .http_headers = headers,
        };
    }

    pub fn deinit(self: *ZiggycordHttpClient) void {
        self.http_client.deinit();
        self.http_headers.deinit();
    }

    const QueryResponse = struct {
        body: []const u8,
        status: http.Status,
    };

    fn queryDiscord(self: *ZiggycordHttpClient, method: http.Method, comptime path: []const u8) !QueryResponse {
        var req = try self.http_client.request(method, std.Uri.parse(BASE_URL ++ path) catch unreachable, self.http_headers, self.http_options);
        defer req.deinit();
        try req.start();
        try req.wait();

        const body = try req.reader().readAllAlloc(self.allocator, 65535);
        return .{ .body = body, .status = req.response.status };
    }

    pub fn getSelf(self: *ZiggycordHttpClient) !void {
        var res = try queryDiscord(self, .GET, "/users/@me");
        defer self.allocator.free(res.body);
        std.debug.print("status code: {d}\n", .{@intFromEnum(res.status)});
        std.debug.print("res from server: {s}\n", .{res.body});
    }
};
