const testing = @import("std").testing;

pub const GUILDS = (1 << 0);
pub const GUILD_MEMBERS = (1 << 1);
pub const GUILD_MODERATION = (1 << 2);
pub const GUILD_EMOJIS_AND_STICKERS = (1 << 3);
pub const GUILD_INTEGRATIONS = (1 << 4);
pub const GUILD_WEBHOOKS = (1 << 5);
pub const GUILD_INVITES = (1 << 6);
pub const GUILD_VOICE_STATES = (1 << 7);
pub const GUILD_PRESENCES = (1 << 8);
pub const GUILD_MESSAGES = (1 << 9);
pub const GUILD_MESSAGE_REACTIONS = (1 << 10);
pub const GUILD_MESSAGE_TYPING = (1 << 11);

pub const DIRECT_MESSAGES = (1 << 12);
pub const DIRECT_MESSAGE_REACTIONS = (1 << 13);
pub const DIRECT_MESSAGE_TYPING = (1 << 14);
pub const MESSAGE_CONTENT = (1 << 15);
pub const GUILD_SCHEDULED_EVENTS = (1 << 16);
pub const AUTO_MODERATION_CONFIGURATION = (1 << 20);
pub const AUTO_MODERATION_EXECUTION = (1 << 21);

test "intents work (no idea why they shouldn't)" {
    try testing.expectEqual(2098176, GUILD_MESSAGE_REACTIONS | AUTO_MODERATION_EXECUTION);
}
