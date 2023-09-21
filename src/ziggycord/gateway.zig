const std = @import("std");
const builtin = @import("builtin");
const json = std.json;
const log = std.log.scoped(.gateway);

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

        sequence: ?i64 = null,
        heart_handle: ?*std.Thread.ResetEvent = null,

        pub fn handle(self: *@This(), message: websocket.Message) !void {
            const start = std.time.nanoTimestamp();

            const data = message.data;
            log.debug("R <- data: {s}", .{data});

            var arena = ArenaAllocator.init(self.gateway_client.allocator);
            defer arena.deinit();
            const allocator = arena.allocator();

            const res = try json.parseFromSliceLeaky(types.GatewayMessage, allocator, data, .{});
            // set the sequence to the current one
            self.sequence = res.s;

            switch (res.op) {
                10 => {
                    // hello opcode
                    if (res.d) |raw_data| {
                        const hello = try json.parseFromValueLeaky(types.GatewayR10Hello, allocator, raw_data, IGNORE_UNNOWN);
                        const pause = @as(u32, @intFromFloat(self.gateway_client.jitter * @as(f32, @floatFromInt(hello.heartbeat_interval))));
                        const interval = hello.heartbeat_interval;

                        log.debug("R op10hello, heartbeat interval: {d}ms (first beat delay {d}ms)", .{
                            pause,
                            interval,
                        });

                        if (self.heart_handle != null) {
                            std.log.err("Hello from gateway improperly recieved twice, ignoring 2nd one...", .{});
                        }

                        // TODO: launch heart 🚀
                        var heart_handle = std.Thread.ResetEvent{};
                        self.heart_handle = &heart_handle;
                        const thread = try std.Thread.spawn(.{}, start_heart, .{ self, pause, interval });
                        thread.detach();

                        const identify = types.GatewayT2Identify{
                            .token = self.gateway_client.http.token,
                            .intents = self.gateway_client.intents,
                            .properties = types.IdentifyConnectionProperties{
                                .os = @tagName(builtin.os.tag),
                                .browser = "ziggycord",
                                .device = "ziggycord",
                            },
                        };

                        try self.transmit(allocator, types.GatewayT2Identify, identify, 2);
                    }
                },

                else => {
                    log.debug("R !! unknown op{d}", .{res.op});
                },
            }

            const time = std.time.nanoTimestamp() - start;
            log.debug("R <- processed in {d:.2}ms", .{@as(f64, @floatFromInt(time)) / std.time.ns_per_ms});
        }

        fn start_heart(self: *@This(), start_after: u32, interval: u32) !void {
            const heart_handle = self.heart_handle.?;
            var delay = start_after;
            log.debug("<3 heart started {d}ms -> {d}ms", .{ start_after, interval });
            while (!heart_handle.isSet()) {
                heart_handle.timedWait(@as(u64, delay) * std.time.ns_per_ms) catch {};
                if (heart_handle.isSet()) {
                    log.debug("</3 cardiac arrest", .{});
                    break;
                }

                var arena = ArenaAllocator.init(self.gateway_client.allocator);
                defer arena.deinit();
                const allocator = arena.allocator();

                log.debug("<3 THUMP", .{});
                self.transmit(allocator, ?i64, self.sequence, 1) catch {
                    arena.deinit();
                };

                delay = interval;
            }
        }

        fn transmit(self: @This(), allocator: Allocator, comptime T: type, data: T, op: u8) !void {
            const message = types.GatewayMessageOutgoing(T){ .op = op, .d = data, .s = self.sequence };

            var list = std.ArrayList(u8).init(allocator);
            errdefer list.deinit();
            try json.stringifyArbitraryDepth(allocator, message, .{}, list.writer());
            var slice = try list.toOwnedSlice();
            log.debug("T -> op{d} {s}", .{ op, slice });

            try self.client.write(slice);
        }

        pub fn close(self: @This()) void {
            log.debug("R <- !! gateway closed connection !!", .{});
            if (self.heart_handle) |heart_handle| {
                heart_handle.set();
            }
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

        log.debug("T -> !! opening gateway connection !!", .{});
        try client.handshake("/?v=10&encoding=json", .{
            .timeout_ms = 5000,
            .headers = formattedHost,
        });

        var handler = Handler{ .client = &client, .gateway_client = self };
        try client.readLoop(&handler);
    }
};
