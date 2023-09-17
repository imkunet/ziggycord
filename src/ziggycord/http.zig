const std = @import("std");
const http = std.http;
const json = std.json;

const Allocator = std.mem.Allocator;
const ArenaAllocator = std.heap.ArenaAllocator;

const types = @import("types.zig");

const BASE_URL = "https://discord.com/api/v10";
const VERSION = "0.0.1";
const USER_AGENT = std.fmt.comptimePrint("Ziggycord (https://github.com/imkunet/ziggycord/, v{s})", .{VERSION});

const PARSE_OPTIONS = .{ .ignore_unknown_fields = true };

pub const HttpClient = struct {
    allocator: Allocator,
    token: []const u8,

    http_client: http.Client,
    http_options: http.Client.Options,
    http_headers: http.Headers,

    pub fn init(allocator: Allocator, token: []const u8) !HttpClient {
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

    pub fn deinit(self: *@This()) void {
        self.http_client.deinit();
        self.http_headers.deinit();
    }

    const QueryResponse = struct {
        body: []const u8,
        status: http.Status,
    };

    fn queryDiscord(self: *@This(), allocator: Allocator, method: http.Method, url: []const u8) !QueryResponse {
        const uri = try std.Uri.parse(url);
        var req = try self.http_client.request(method, uri, self.http_headers, self.http_options);
        defer req.deinit();
        try req.start();
        try req.wait();

        // hopefully 4MB will be enough to store the data from a single request
        // the highest I can imagine Discord returning ATM is a 100 message batch
        // filled with content and metadata
        const body = try req.reader().readAllAlloc(allocator, 4_000_000);
        return .{ .body = body, .status = req.response.status };
    }

    fn formatUrl(
        self: *@This(),
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

    fn ApiResponse(comptime T: type) type {
        return struct {
            arena: ArenaAllocator,
            value: T,

            pub fn deinit(self: @This()) void {
                self.arena.deinit();
            }
        };
    }

    pub fn getSelf(self: *@This()) !ApiResponse(types.User) {
        var arena = ArenaAllocator.init(self.allocator);
        const allocator = arena.allocator();

        const res = try queryDiscord(self, allocator, .GET, comptime fixedUrl("/users/@me"));
        const parsed = try json.parseFromSliceLeaky(types.User, allocator, res.body, PARSE_OPTIONS);

        return ApiResponse(types.User){
            .arena = arena,
            .value = parsed,
        };
    }
};
