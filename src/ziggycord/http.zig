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

    pub fn init(allocator: Allocator, token: []const u8) !@This() {
        const token_formatted = try std.fmt.allocPrint(allocator, "Bot {s}", .{token});

        var headers = http.Headers.init(allocator);
        try headers.append("Authorization", token_formatted);
        try headers.append("User-Agent", USER_AGENT);
        try headers.append("Content-Type", "application/json");
        try headers.append("Accept", "application/json");
        headers.sort();

        return .{
            .allocator = allocator,
            .token = token_formatted,
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
        self.allocator.free(self.token);
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

    fn fixedUrl(comptime path: []const u8) []const u8 {
        return BASE_URL ++ path;
    }

    fn ApiResponse(comptime T: type) type {
        return struct {
            arena: ArenaAllocator,
            value: T,

            fn init(arena: ArenaAllocator, value: T) @This() {
                return .{
                    .arena = arena,
                    .value = value,
                };
            }

            fn fromQuery(client: *HttpClient, method: http.Method, url: []const u8) !@This() {
                var arena = ArenaAllocator.init(client.allocator);
                const arena_allocator = arena.allocator();

                const res = try client.queryDiscord(arena_allocator, method, url);
                const parsed = try json.parseFromSliceLeaky(T, arena_allocator, res.body, PARSE_OPTIONS);

                return ApiResponse(T){ .arena = arena, .value = parsed };
            }

            pub fn deinit(self: @This()) void {
                self.arena.deinit();
            }
        };
    }

    pub fn getSelf(self: *@This()) !ApiResponse(types.User) {
        return ApiResponse(types.User).fromQuery(self, .GET, comptime fixedUrl("/users/@me"));
    }

    pub fn getGatewayBot(self: *@This()) !ApiResponse(types.BotGateway) {
        return ApiResponse(types.BotGateway).fromQuery(self, .GET, comptime fixedUrl("/gateway/bot"));
    }
};
