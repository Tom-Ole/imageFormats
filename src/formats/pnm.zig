const std = @import("std");

const Self = @This();

pub const FILE_TYPES = enum {
    BITMAP_ASCII,
    GRAYMAP_ASCII,
    PIXMAP_ASCII,
    BITMAP_BINARY,
    GRAYMAP_BINARY,
    PIXMAP_BINARY,
};

file_type: FILE_TYPES,
width: u32,
height: u32,
data: []u8,

pub fn create(width: u32, height: u32, data: []u8, file_type: ?FILE_TYPES) Self {
    return .{
        .file_type = file_type orelse FILE_TYPES.PIXMAP_ASCII,
        .width = width,
        .height = height,
        .data = data,
    };
}

fn write_data(self: Self, file: std.fs.File) !void {
    const writer = file.writer();

    switch (self.file_type) {
        .BITMAP_ASCII, .GRAYMAP_ASCII => {
            var i: usize = 0;
            for (0..self.height) |_| {
                for (0..self.width) |_| {
                    try writer.print("{d} ", .{self.data[i]});
                    i += 1;
                }
                try writer.writeByte('\n');
            }
        },
        .PIXMAP_ASCII => {
            var i: usize = 0;
            for (0..self.height) |_| {
                for (0..self.width) |_| {
                    const r = self.data[i];
                    const g = self.data[i + 1];
                    const b = self.data[i + 2];
                    try writer.print("{d} {d} {d} ", .{ r, g, b });
                    i += 3;
                }
                try writer.writeByte('\n');
            }
        },
        .BITMAP_BINARY => {
            // TODO: pack 8 pixels into 1 byte
        },
        .GRAYMAP_BINARY, .PIXMAP_BINARY => {
            try writer.writeAll(self.data);
        },
    }
}

fn file_end(self: Self) *const [4]u8 {
    return switch (self.file_type) {
        .BITMAP_ASCII, .BITMAP_BINARY => ".pbm",
        .GRAYMAP_ASCII, .GRAYMAP_BINARY => ".pgm",
        .PIXMAP_ASCII, .PIXMAP_BINARY => ".ppm",
    };
}

pub fn create_image(self: Self, file_name: []const u8) !void {
    const allocator = std.heap.page_allocator;

    const file_ending = self.file_end();

    var name: []u8 = undefined;

    if (!std.mem.endsWith(u8, file_name, file_ending)) {
        name = try std.mem.concat(allocator, u8, &.{ file_name, file_ending });
    } else {
        name = try allocator.dupe(u8, file_name);
    }
    defer allocator.free(name);

    const file = try std.fs.cwd().createFile(name, .{});
    defer file.close();

    const writer = file.writer();

    const header = switch (self.file_type) {
        .BITMAP_ASCII => "P1",
        .GRAYMAP_ASCII => "P2",
        .PIXMAP_ASCII => "P3",
        .BITMAP_BINARY => "P4",
        .GRAYMAP_BINARY => "P5",
        .PIXMAP_BINARY => "P6",
    };

    _ = try writer.writeAll(header);
    try writer.writeByte('\n');

    try writer.print("{d} {d} ", .{ self.width, self.height });

    switch (self.file_type) {
        .BITMAP_ASCII, .BITMAP_BINARY => {
            try writer.writeByte('\n');
        }, // PBM has no maxval
        else => try writer.print("{d}\n", .{255}),
    }

    try self.write_data(file);
}
