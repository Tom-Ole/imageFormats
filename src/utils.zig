pub fn u32le(n: u32) [4]u8 {
    const o1: u8 = @intCast(((n >> 24) & 0xff));
    const o2: u8 = @intCast(((n >> 16) & 0xff));
    const o3: u8 = @intCast(((n >> 8) & 0xff));
    const o4: u8 = @intCast(((n >> 0) & 0xff));

    return .{ o4, o3, o2, o1 };
}

pub fn u16le(n: u16) [2]u8 {
    const o1: u8 = @intCast(((n >> 8) & 0xff));
    const o2: u8 = @intCast(((n >> 0) & 0xff));

    return .{ o2, o1 };
}
