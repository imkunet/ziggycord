const std = @import("std");

/// a "snowflake" is an ID in the Discord ecosystem
pub const snowflake = @import("snowflake.zig");
const Snowflake = snowflake.Snowflake;

pub const User = struct {
    id: Snowflake,
    username: []const u8,
    discriminator: []const u8,
};

pub const SessionStartLimit = struct {
    /// Total number of session starts the current user is allowed
    total: i32,
    /// Remaining number of session starts the current user is allowed
    remaining: i32,
    /// Number of milliseconds after which the limit resets
    reset_after: i32,
    /// Number of identify requests allowed per 5 seconds
    max_concurrency: i32,
};

pub const BotGateway = struct {
    url: []const u8,
    /// Recommended number of shards to use when connecting
    shards: i32,
    /// Information on the current session start limit
    session_start_limit: SessionStartLimit,
};

pub const GatewayMessage = struct {
    op: u8,
    d: ?std.json.Value,
    s: ?i32,
    t: ?[]const u8,
};

pub const GatewayR10Hello = struct {
    heartbeat_interval: u32,
};

pub const IdentifyConnectionProperties = struct {
    os: []const u8,
    browser: []const u8,
    device: []const u8,
};

pub const GatewayT2Identify = struct {
    token: []const u8,
    properties: IdentifyConnectionProperties,
    // coming soon: compression o_O?, shard, large_threshold, presence
    intents: u32,
};
