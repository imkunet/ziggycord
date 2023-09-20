const std = @import("std");
const json = std.json;
const log = std.log.scoped(.Gateway);

const Allocator = std.mem.Allocator;
const ArenaAllocator = std.heap.ArenaAllocator;

const HttpClient = @import("http.zig").HttpClient;
const types = @import("types.zig");
const websocket = @import("websocket");

/// Intents are the way to tell the Gateway what extra permissions your bot needs
pub const GatewayIntents = @import("intents.zig");

const IGNORE_UNNOWN = .{ .ignore_unknown_fields = true };

pub const GatewayConnectionError = error{
    InvalidGatewayHost,
};

/// Discord's "Gateway" is the way bots recieve events
pub const GatewayClient = struct {
    allocator: Allocator,
    http: HttpClient,

    jitter: f32,
    intents: u32,

    /// Create a new GatewayClient, needs an HttpClient
    pub fn init(allocator: Allocator, http: HttpClient) !@This() {
        return .{
            .allocator = allocator,
            .http = http,
            .jitter = std.crypto.random.float(f32),
            .intents = GatewayIntents.DEFAULT,
        };
    }

    pub fn deinit(self: *@This()) void {
        _ = self;
        // do something here
    }

    const Handler = struct {
        gateway_client: *GatewayClient,
        client: *websocket.Client,

        pub fn handle(self: @This(), message: websocket.Message) !void {
            const start = std.time.nanoTimestamp();

            const data = message.data;
            log.debug("R <- data: {s}", .{data});

            var arena = ArenaAllocator.init(self.gateway_client.allocator);
            const allocator = arena.allocator();

            const res = try json.parseFromSliceLeaky(types.GatewayMessage, allocator, data, .{});

            switch (res.op) {
                10 => {
                    // hello opcode
                    if (res.d) |raw_data| {
                        const hello = try json.parseFromValueLeaky(types.Gateway10Hello, allocator, raw_data, IGNORE_UNNOWN);
                        log.debug("R op10hello, heartbeat interval: {d}ms (first beat delay {d:.2}ms)", .{
                            hello.heartbeat_interval,
                            self.gateway_client.jitter * @as(f32, @floatFromInt(hello.heartbeat_interval)),
                        });

                        // TODO: launch heart 🚀
                        const identify = types.GatewayT2Identify{
                            .token = self.gateway_client.http.token,
                            .intents = self.gateway_client.intents,
                            .properties = types.IdentifyConnectionProperties{
                                .os = "linux",
                                .browser = "ziggycord",
                                .device = "ziggycord",
                            },
                        };

                        // TODO: make this work going to bed
                        //const identify_message = types.GatewayMessage{
                        //    .op = 2,

                        //}
                        _ = identify;
                    }
                },

                else => {
                    log.debug("R !! unknown op{d}", .{res.op});
                },
            }

            arena.deinit();

            const time = std.time.nanoTimestamp() - start;
            log.debug("R <- finished in {d:.2}ms", .{@as(f64, @floatFromInt(time)) / std.time.ns_per_ms});
        }

        pub fn close(self: @This()) void {
            log.debug("R <- !! gateway closed connection !!", .{});
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

        var client = try websocket.connect(self.allocator, host, 443, .{
            .tls = true,
            .ca_bundle = self.http.http_client.ca_bundle,
        });
        defer client.deinit();

        const formattedHost = try std.fmt.allocPrint(self.allocator, "host: {s}\r\n", .{host});
        defer self.allocator.free(formattedHost);

        log.debug("T <- !! opening gateway connection !!", .{});
        try client.handshake("/?v=10&encoding=json", .{
            .timeout_ms = 5000,
            .headers = formattedHost,
        });

        const handler = Handler{ .client = &client, .gateway_client = self };
        try client.readLoop(handler);
    }
};
