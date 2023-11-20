const std = @import("std");
const http = std.http;
const json = std.json;

const Allocator = std.mem.Allocator;
const ArenaAllocator = std.heap.ArenaAllocator;

const types = @import("types.zig");

const BASE_URL = "https://discord.com/api/v10";
const VERSION = "0.0.1";
const USER_AGENT = std.fmt.comptimePrint("Ziggycord (https://github.com/imkunet/ziggycord/, v{s})", .{VERSION});

const PARSE_OPTIONS = .{
    .ignore_unknown_fields = true,
    .allocate = .alloc_always,
};

pub const HttpClient = struct {
    allocator: Allocator,
    token: []const u8,

    http_client: http.Client,
    http_options: http.Client.RequestOptions,
    http_headers: http.Headers,

    pub fn init(allocator: Allocator, token: []const u8) !@This() {
        const token_formatted = try std.fmt.allocPrint(allocator, "Bot {s}", .{token});

        var headers = http.Headers.init(allocator);
        try headers.append("Accept", "application/json");
        try headers.append("Authorization", token_formatted);
        try headers.append("Content-Type", "application/json");
        try headers.append("User-Agent", USER_AGENT);
        headers.sort();

        return .{
            .allocator = allocator,
            .token = token_formatted,
            .http_client = .{
                .allocator = allocator,
            },
            .http_options = .{},
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

        var res = try self.http_client.fetch(allocator, .{
            .method = method,
            .location = http.Client.FetchOptions.Location{ .uri = uri },
            .headers = self.http_headers,
        });
        defer res.deinit();

        var buffer = try allocator.alloc(u8, res.body.?.len);
        std.mem.copy(u8, buffer, res.body.?);

        for (res.headers.list.items) |value| {
            std.log.info("{s}: {s}", .{ value.name, value.value });
        }

        return .{ .body = buffer, .status = res.status };
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
                arena_allocator.free(res.body);

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
