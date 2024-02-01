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

const IGNORE_UNKNOWN = .{ .ignore_unknown_fields = true };

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
        heart_handle: std.Thread.ResetEvent = std.Thread.ResetEvent{},
        heart_interval: u32 = 30_000,
        heart_last_beat: i64 = -1,
        heart_started: bool = false,

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
                        const hello = try json.parseFromValueLeaky(types.GatewayR10Hello, allocator, raw_data, IGNORE_UNKNOWN);
                        const pause = @as(u32, @intFromFloat(self.gateway_client.jitter * @as(f32, @floatFromInt(hello.heartbeat_interval))));
                        self.heart_interval = hello.heartbeat_interval;

                        log.debug("R op10hello, heartbeat interval: {d}ms (first beat delay {d}ms)", .{ self.heart_interval, pause });

                        if (@cmpxchgStrong(bool, &self.heart_started, false, true, .Monotonic, .Monotonic) == null) {
                            const thread = try std.Thread.spawn(.{
                                .stack_size = 4 * 1024 * 1024, // 4MB, we'll see how it goes...
                            }, start_heart, .{ self, pause });
                            thread.detach();
                        } else {
                            log.debug("R op10 recieved while heart beating, not starting another heart...", .{});
                        }

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

                11 => {
                    const ping_time = std.time.milliTimestamp() - @atomicRmw(i64, &self.heart_last_beat, .Xchg, -1, .Monotonic);
                    log.debug("<3 PONG (RTT {d}ms)", .{ping_time});
                },

                else => {
                    log.debug("R !! unknown op{d}", .{res.op});
                },
            }

            const time = std.time.nanoTimestamp() - start;
            log.debug("R <- processed in {d:.2}ms", .{@as(f64, @floatFromInt(time)) / std.time.ns_per_ms});
        }

        fn start_heart(self: *@This(), start_after: u32) !void {
            var delay = start_after;
            log.debug("<3 heart started ({d}ms -> {d}ms)", .{ start_after, self.heart_interval });

            while (!self.heart_handle.isSet()) {
                self.heart_handle.timedWait(@as(u64, delay) * std.time.ns_per_ms) catch {};
                if (self.heart_handle.isSet()) break;

                var arena = ArenaAllocator.init(self.gateway_client.allocator);
                const allocator = arena.allocator();

                log.debug("<3 PING", .{});
                if (@cmpxchgWeak(i64, &self.heart_last_beat, -1, std.time.milliTimestamp(), .Monotonic, .Monotonic) != null) {
                    log.debug("</3 double ping (no response since last ping)", .{});
                    self.client.close();
                    return;
                }
                self.transmit(allocator, ?i64, self.sequence, 1) catch |why| {
                    arena.deinit();
                    log.debug("</3 ping error {!} (cardiac arresting)", .{why});
                    self.client.close();
                    return;
                };

                arena.deinit();
                delay = self.heart_interval;
            }

            log.debug("</3 cardiac arrest", .{});
        }

        fn transmit(self: *@This(), allocator: Allocator, comptime T: type, data: T, op: u8) !void {
            const message = types.GatewayMessageOutgoing(T){ .op = op, .d = data, .s = self.sequence };

            var list = std.ArrayList(u8).init(allocator);
            errdefer list.deinit();
            try json.stringifyArbitraryDepth(allocator, message, .{}, list.writer());
            const slice = try list.toOwnedSlice();
            log.debug("T -> op{d} {s}", .{ op, slice });

            try self.client.write(slice);
        }

        pub fn close(self: *@This()) void {
            log.debug("stopping heart...", .{});
            self.heart_handle.set();
            log.debug("R <- !! gateway closed connection !!", .{});
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
            .headers = formattedHost,
        });

        var handler = Handler{
            .client = &client,
            .gateway_client = self,
        };
        try client.readLoop(&handler);

        log.debug("exited", .{});
    }
};
