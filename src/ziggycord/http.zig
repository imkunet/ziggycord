const std = @import("std");
const http = std.http;

const BASE_URL = "https://discord.com/api/v10";
const VERSION = "0.0.1";
const USER_AGENT = std.fmt.comptimePrint("Ziggycord (https://github.com/imkunet/ziggycord/, v{s})", .{VERSION});

pub const HttpClient = struct {
    allocator: std.mem.Allocator,
    token: []const u8,

    http_client: http.Client,
    http_options: http.Client.Options,
    http_headers: http.Headers,

    pub fn init(allocator: std.mem.Allocator, token: []const u8) !HttpClient {
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

    pub fn deinit(self: *HttpClient) void {
        self.http_client.deinit();
        self.http_headers.deinit();
    }

    const QueryResponse = struct {
        body: []const u8,
        status: http.Status,
    };

    fn queryDiscord(self: *HttpClient, method: http.Method, url: []const u8) !QueryResponse {
        const uri = try std.Uri.parse(url);
        var req = try self.http_client.request(method, uri, self.http_headers, self.http_options);
        defer req.deinit();
        try req.start();
        try req.wait();

        // hopefully 4MB will be enough to store the data from a single request
        // the highest I can imagine Discord returning ATM is a 100 message batch
        // filled with content and metadata
        const body = try req.reader().readAllAlloc(self.allocator, 4_000_000);
        return .{ .body = body, .status = req.response.status };
    }

    fn formatUrl(
        self: *HttpClient,
        comptime format: []const u8,
        args: anytype,
    ) void {
        _ = args;
        _ = format;
        _ = self;
    }

    fn fixedUrl(comptime path: []const u8) []const u8 {
        return BASE_URL ++ path;
    }

    pub fn getSelf(self: *HttpClient) !void {
        var res = try queryDiscord(self, .GET, comptime fixedUrl("/users/@me"));
        defer self.allocator.free(res.body);

        std.debug.print("status code: {d}\n", .{@intFromEnum(res.status)});
        std.debug.print("res from server: {s}\n", .{res.body});
    }
};
