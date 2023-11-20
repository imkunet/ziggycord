const std = @import("std");
const fmt = std.fmt;

/// A unique Discord ID which is chronologically sortable;
/// contains a timestamp and some other metadata
pub const Snowflake = []const u8;

const Allocator = std.mem.Allocator;
const allocPrint = fmt.allocPrint;

// Discord's "beginning of the universe", the first second of 2015
pub const DISCORD_EPOCH = 1420070400000;

/// converts a snowflake to a Discord timestamp (milliseconds from the first second of 2015)
pub fn snowflakeToDiscordTimestamp(snowflake: Snowflake) !i64 {
    return try fmt.parseInt(i64, snowflake, 10) >> 22;
}

/// converts a snowflake to a UNIX timestamp (milliseconds from Jan 1, 1970 UTC)
pub fn snowflakeToTimestamp(snowflake: Snowflake) !i64 {
    return try snowflakeToDiscordTimestamp(snowflake) + DISCORD_EPOCH;
}

/// converts a UNIX timestamp (im milliseconds) to a snowflake useful for pagination
pub fn timestampToSnowflake(allocator: Allocator, timestamp: i64) !Snowflake {
    return allocPrint(allocator, "{d}", .{(timestamp - DISCORD_EPOCH) << 22});
}

pub fn snowflakeToUserMention(allocator: Allocator, snowflake: Snowflake) ![]u8 {
    return allocPrint(allocator, "<@{s}>", .{snowflake});
}

pub fn snowflakeToRoleMention(allocator: Allocator, snowflake: Snowflake) ![]u8 {
    return allocPrint(allocator, "<@&{s}>", .{snowflake});
}

pub fn snowflakeToChannelMention(allocator: Allocator, snowflake: i64) ![]u8 {
    return allocPrint(allocator, "<#{d}>", .{snowflake});
}

test "timestampFromSnowflake" {
    try std.testing.expect(1694531276785 == try snowflakeToTimestamp("1151172353343094815"));
}
