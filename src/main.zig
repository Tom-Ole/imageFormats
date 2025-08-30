const std = @import("std");
const bmp = @import("formats/bmp.zig");
const pnm = @import("formats/pnm.zig");
const png = @import("formats/png.zig");

pub fn main() !void {
    const alloc = std.heap.page_allocator;

    const width = 300;
    const height = 300;
    var test_data: []u8 = try alloc.alloc(u8, width * height * 3);
    defer alloc.free(test_data);

    for (0..height) |y| {
        for (0..width) |x| {
            const r: u8 = @intCast((y * 255) / height);
            const b: u8 = @intCast((x * 255) / width);

            const idx = (y * width + x) * 3;
            test_data[idx] = r;
            test_data[idx + 1] = 0;
            test_data[idx + 2] = b;
        }
    }

    const image = try png.create(alloc);
    _ = image;
}

test "pnm PMP" {
    const alloc = std.heap.page_allocator;

    const width = 300;
    const height = 300;
    var test_data: []u8 = try alloc.alloc(u8, width * height * 3);
    defer alloc.free(test_data);

    for (0..height) |y| {
        for (0..width) |x| {
            const r: u8 = @intCast((y * 255) / height);
            const b: u8 = @intCast((x * 255) / width);

            const idx = (y * width + x) * 3;
            test_data[idx] = r;
            test_data[idx + 1] = 0;
            test_data[idx + 2] = b;
        }
    }

    const image = pnm.create(width, height, test_data, pnm.FILE_TYPES.PIXMAP_ASCII);
    try image.create_image("Test.ppm");
}

test "bpm" {
    const alloc = std.heap.page_allocator;

    const width = 300;
    const height = 300;
    var test_data: []u8 = try alloc.alloc(u8, width * height * 3);
    defer alloc.free(test_data);

    for (0..height) |y| {
        for (0..width) |x| {
            const r: u8 = @intCast((y * 255) / height);
            const b: u8 = @intCast((x * 255) / width);

            const idx = (y * width + x) * 3;
            test_data[idx] = r;
            test_data[idx + 1] = 0;
            test_data[idx + 2] = b;
        }
    }

    const image = bmp.create(alloc, width, height, test_data);
    defer image.deinit();
    try image.create_image("Test.bmp");
}
