const std = @import("std");
const fmt = std.fmt;

const Allocator = std.mem.Allocator;
const allocPrint = fmt.allocPrint;
const AllocPrintError = fmt.AllocPrintError;

const DISCORD_EPOCH = 1420070400000;

/// converts a snowflake to a Discord timestamp (milliseconds from the first second of 2015)
pub fn snowflakeToDiscordTimestamp(snowflake: i64) i64 {
    return snowflake >> 22;
}

/// converts a snowflake to a UNIX timestamp (milliseconds from Jan 1, 1970 UTC)
pub fn snowflakeToTimestamp(snowflake: i64) i64 {
    return snowflakeToDiscordTimestamp(snowflake) + DISCORD_EPOCH;
}

/// converts a UNIX timestamp (im milliseconds) to a snowflake useful for pagination
pub fn timestampToSnowflake(timestamp: i64) i64 {
    return (timestamp - DISCORD_EPOCH) << 22;
}

pub fn snowflakeToUserMention(allocator: Allocator, snowflake: i64) AllocPrintError![]u8 {
    return allocPrint(allocator, "<@{d}>", .{snowflake});
}

pub fn snowflakeToRoleMention(allocator: Allocator, snowflake: i64) AllocPrintError![]u8 {
    return allocPrint(allocator, "<@&{d}>", .{snowflake});
}

pub fn snowflakeToChannelMention(allocator: Allocator, snowflake: i64) AllocPrintError![]u8 {
    return allocPrint(allocator, "<#{d}>", .{snowflake});
}

test "timestampFromSnowflake" {
    try std.testing.expect(1694531276785 == snowflakeToTimestamp(1151172353343094815));
}
