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
