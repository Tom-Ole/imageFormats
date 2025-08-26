const std = @import("std");

const utils = @import("utils");
const u32le = utils.u32le;
const u16le = utils.u16le;

const Self = @This();

alloc: std.mem.Allocator,

header: Header,

data: []u8, // [[r, b, g, r]]

const Header = struct {
    // File Header
    signature: [2]u8,
    file_size: [4]u8,
    reserved: [4]u8,
    data_offset: [4]u8,

    // Info Header
    size: [4]u8,
    width: [4]u8,
    height: [4]u8,
    planes: [2]u8,
    bit_count: [2]u8,
    compression: [4]u8,
    image_size: [4]u8,
    x_pixels_per_m: [4]u8,
    y_pixels_per_m: [4]u8,
    colors_used: [4]u8,
    colors_important: [4]u8,

    pub fn new(width: u32, height: u32) Header {
        const header_size: u32 = 14 + 40;
        const pixel_size: u32 = width * height * 4;

        return .{
            .signature = .{ 'B', 'M' },
            .file_size = u32le(header_size + pixel_size),
            .reserved = .{ 0, 0, 0, 0 },
            .data_offset = u32le(header_size),

            .size = u32le(40),
            .width = u32le(width),
            .height = u32le(height),
            .planes = u16le(1),
            .bit_count = u16le(32), // since setRGB makes 4 bytes/pixel
            .compression = u32le(0),
            .image_size = u32le(pixel_size),
            .x_pixels_per_m = u32le(0),
            .y_pixels_per_m = u32le(0),
            .colors_used = u32le(0),
            .colors_important = u32le(0),
        };
    }
};

fn setRGB(r: u8, g: u8, b: u8) [4]u8 {
    return .{ b, g, r, 255 };
}

fn setData(alloc: std.mem.Allocator, width: usize, height: usize, data: []u8) []u8 {
    var out: []u8 = alloc.alloc(u8, width * height * 4) catch unreachable;

    for (0..height) |y| {
        for (0..width) |x| {
            const row_idx = height - 1 - y;
            const idx = (row_idx * width + x) * 3;
            const bgr = setRGB(data[idx], data[idx + 1], data[idx + 2]);

            const out_idx = (y * width + x) * 4;
            out[out_idx] = bgr[0];
            out[out_idx + 1] = bgr[1];
            out[out_idx + 2] = bgr[2];
            out[out_idx + 3] = bgr[3];
        }
    }

    return out;
}

pub fn create(alloc: std.mem.Allocator, width: u32, height: u32, data: []u8) Self {
    return .{
        .alloc = alloc,
        .header = Header.new(width, height),
        .data = setData(alloc, width, height, data),
    };
}

fn flatten_header(self: Self) []u8 {
    var out: []u8 = self.alloc.alloc(u8, 54) catch unreachable;

    out[0..2].* = self.header.signature;
    out[2..6].* = self.header.file_size;
    out[6..10].* = self.header.reserved;
    out[10..14].* = self.header.data_offset;

    // Info self.header
    out[14..18].* = self.header.size;
    out[18..22].* = self.header.width;
    out[22..26].* = self.header.height;
    out[26..28].* = self.header.planes;
    out[28..30].* = self.header.bit_count;
    out[30..34].* = self.header.compression;
    out[34..38].* = self.header.image_size;
    out[38..42].* = self.header.x_pixels_per_m;
    out[42..46].* = self.header.y_pixels_per_m;
    out[46..50].* = self.header.colors_used;
    out[50..54].* = self.header.colors_important;

    return out;
}

pub fn create_image(self: Self, file_name: []const u8) !void {
    const file = try std.fs.cwd().createFile(file_name, .{});
    defer file.close();

    const header = self.flatten_header();

    _ = try file.write(header);
    _ = try file.write(self.data);
}

pub fn deinit(self: Self) void {
    self.alloc.free(self.data);
}
