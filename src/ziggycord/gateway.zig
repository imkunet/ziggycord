const std = @import("std");

const Allocator = std.mem.Allocator;

const HttpClient = @import("http.zig").HttpClient;
const types = @import("types.zig");
const websocket = @import("websocket");

const GatewayConnectionError = error{
    InvalidGatewayHost,
};

pub const GatewayClient = struct {
    allocator: Allocator,
    http: HttpClient,

    jitter: f32,

    pub fn init(allocator: Allocator, http: HttpClient) !@This() {
        return .{
            .allocator = allocator,
            .http = http,
            .jitter = std.crypto.random.float(f32),
        };
    }

    const Handler = struct {
        client: *websocket.Client,

        pub fn handle(self: @This(), message: websocket.Message) !void {
            _ = self;
            const data = message.data;
            std.log.debug("data from socket: {s}", .{data});
        }

        pub fn close(self: @This()) void {
            _ = self;
        }
    };

    pub fn connect(self: *@This()) !void {
        const gateway_details = try self.http.getGatewayBot();
        defer gateway_details.deinit();

        if (!std.mem.startsWith(u8, gateway_details.value.url, "wss://")) {
            return GatewayConnectionError.InvalidGatewayHost;
        }
        const host = gateway_details.value.url[6..];

        var client = try websocket.connect(self.allocator, host, 443, .{ .tls = true });
        defer client.deinit();

        const formattedHost = try std.fmt.allocPrint(self.allocator, "host: {s}\r\n", .{host});
        defer self.allocator.free(formattedHost);

        try client.handshake("/?v=10&encoding=json", .{
            .timeout_ms = 5000,
            .headers = formattedHost,
        });

        const handler = Handler{ .client = &client };
        try client.readLoop(handler);
    }
};
