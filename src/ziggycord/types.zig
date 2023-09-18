pub const ID = []const u8;

pub const User = struct {
    id: ID,
    username: []const u8,
    discriminator: []const u8,
};
