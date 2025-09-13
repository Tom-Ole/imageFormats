// see: https://libpng.org/pub/png/spec/1.2/PNG-Structure.html

const std = @import("std");
const utils = @import("utils");
const u32le = utils.u32le;
const u16le = utils.u16le;

const Self = @This();

alloc: std.mem.Allocator,
signiture: [8]u8,
ihdr: IHDR,
plte: ?PLTE,
idat: IDAT,
iend: IEND,

// TODO make this more robust, espeacially all cases with color_types etc...
pub fn create(alloc: std.mem.Allocator, width: u32, height: u32, data: []u8) !Self {
    const signiture: [8]u8 = .{ 0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a }; // ASCII: \211   P   N   G  \r  \n \032 \n
    const _IHDR = try IHDR.create(width, height, 8, 2, 0, 0, 0); // TODO: Meaningfull arguments

    var _PLTE: ?PLTE = null;
    var idat_data: []u8 = undefined;

    if (_IHDR.color_type == 3) {
        const quant = try Quant.quantiozeImageToPalette(alloc, data);
        _PLTE = try PLTE.create(alloc, _IHDR.color_type, _IHDR.bit_depth, quant);
        idat_data = quant.indexed;
    } else {
        idat_data = data; // raw RGB or RGBA depending on color_type
    }

    const _IDAT = IDAT.create(alloc, idat_data);
    const _IEND = IEND.create(alloc);

    return .{
        .alloc = alloc,
        .signiture = signiture,
        .ihdr = _IHDR,
        .plte = _PLTE,
        .idat = _IDAT,
        .iend = _IEND,
    };
}

const Chunk = struct {
    // Length of only the chunk_data
    length: u32,

    // consist of uppercase and lowercase ASCII letters;  encoders must treat the codes as fixed binary values,
    //    bLOb  <-- 32 bit chunk type code represented in text form
    //    ||||
    //    |||+- Safe-to-copy bit is 1 (lowercase letter; bit 5 is 1)
    //    ||+-- Reserved bit is 0     (uppercase letter; bit 5 is 0)
    //    |+--- Private bit is 0      (uppercase letter; bit 5 is 0)
    //    +---- Ancillary bit is 1    (lowercase letter; bit 5 is 1)
    chunk_type: [4]u8,

    // data bytes appropriate to the chunk type;
    chunk_data: []u8,

    // crc of chunk_type and chunk_data; NOT the length
    crc: [4]u8, // TODO

    pub fn calculate_crc(self: Chunk) u32 {
        // TODO: implment crc, see: https://libpng.org/pub/png/spec/1.2/PNG-CRCAppendix.html
        self.crc = &.{ 1, 1, 1, 1 };
        return 0;
    }

    pub fn create(chunk_type: [4]u8, chunk_data: []u8) Chunk {
        const length: u32 = 0.0;

        const chunk: Chunk = .{
            .length = length,
            .chunk_type = chunk_type,
            .chunk_data = chunk_data,
            .crc = &.{ 0, 0, 0, 0 },
        };

        chunk.calculate_crc();

        return chunk;
    }
};

// The IDHR Chunk contains the image essetial metadata
const IHDR = struct {
    width: u32,
    height: u32,

    //   Color    Allowed    Interpretation
    //   Type    Bit Depths
    //    0       1,2,4,8,16  Each pixel is a grayscale sample. ;;
    //    2       8,16        Each pixel is an R,G,B triple. ;;
    //    3       1,2,4,8     Each pixel is a palette index;
    //                        a PLTE chunk must appear. ;;
    //    4       8,16        Each pixel is a grayscale sample,
    //                        followed by an alpha sample. ;;
    //    6       8,16        Each pixel is an R,G,B triple,
    //                        followed by an alpha sample. ;;
    bit_depth: u8,
    color_type: u8,
    compresion_method: u8, // TODO research: https://libpng.org/pub/png/spec/1.2/PNG-Compression.html
    filter_method: u8,
    interlace_method: u8,

    pub fn create(width: u32, height: u32, bit_depth: u8, color_type: u8, compresion_method: u8, filter_method: u8, interlace_method: u8) !IHDR {

        const valid_color_type_bit_depth = switch(color_type) {
            0 => contains(&[_]u8{1, 2, 4, 8 , 16}, bit_depth),
            2 => contains(&[_]u8{8 , 16}, bit_depth),
            3 => contains(&[_]u8{1, 2, 4, 8}, bit_depth),
            4 => contains(&[_]u8{8 , 16}, bit_depth),
            6 => contains(&[_]u8{8 , 16}, bit_depth),
            else => false,
        };

        std.debug.print("Bit depth: {}, color_type: {}, valid: {}\n", .{bit_depth, color_type, valid_color_type_bit_depth});


        if (!valid_color_type_bit_depth) return error.InvalidBithDepthColorType;

        return .{
            .width = width,
            .height = height,
            .bit_depth = bit_depth,
            .color_type = color_type,
            .compresion_method = compresion_method,
            .filter_method = filter_method,
            .interlace_method = interlace_method,
        };
    }

    fn contains(list: []const u8, x: u8) bool {
        return std.mem.containsAtLeast(u8, list, 1, &[_]u8{x});
    }

    pub fn to_byte_array(self: IHDR, alloc: std.mem.Allocator) [13]u8 {
        var r: [13]u8 = try alloc.alloc(u8, 13);
        r[0..3].* = u32le(self.width);
        r[4..7].* = u32le(self.height);
        r[8] = self.bit_depth;
        r[9] = self.color_type;
        r[10] = self.compresion_method;
        r[11] = self.filter_method;
        r[12] = self.interlace_method;

        return r;
    }

    pub fn to_chunk(self: IHDR, alloc: std.mem.Allocator) Chunk {
        return Chunk.create(.{ 'I', 'H', 'D', 'R' }, self.create().to_byte_array(alloc));
    }
};


const Quant = struct {
    indexed: []u8,
    palette: []u8,

    const Color = struct {
        r: u8,
        g: u8,
        b: u8,

        pub fn eql(a: Color, b: Color) bool {
            return a.r == b.r and a.g == b.g and a.b == b.b;
        }

        pub fn hash(self: Color) u32 {
            // Simple 24-bit hash
            const ur: u32 = @intCast(self.r);
            const ub: u32 = @intCast(self.g);
            const ug: u32 = @intCast(self.b);
            const hash_u32: u32 = ur << 16 | ug << 8 | ub;
            return hash_u32;
        }
    };

    pub fn quantiozeImageToPalette(alloc: std.mem.Allocator, data: []const u8) !Quant {
        const max_colors = 256;
        const pixel_count = data.len / 3;


        const Map = std.AutoHashMap(Quant.Color, u8);
        var palette_map = Map.init(alloc);

        var palette_buf = try alloc.alloc(u8, max_colors * 3);
        var indexed_buf = try alloc.alloc(u8, pixel_count);

        var next_index: usize = 0;

        var i: usize = 0;
        while (i < data.len) : (i += 3) {
            if (next_index >= 256) {
                std.debug.print("Next_index: {};  i: {} \n", .{next_index, i}); 
                return error.TooManyUniqueColors;
            }
            const color = Color{ 
                .r = data[i],
                .g = data[i+1],
                .b = data[i+2],
            };

            const gop = try palette_map.getOrPut(color);
            if (!gop.found_existing) {
                if (next_index >= max_colors) {
                    return error.TooManyUniqueColors;
                }

                // Wrtite Palette
                palette_buf[next_index * 3 + 0] = color.r;
                palette_buf[next_index * 3 + 1] = color.g;
                palette_buf[next_index * 3 + 2] = color.b;
                gop.value_ptr.* = @as(u8, @intCast(next_index));
                next_index += 1;
            }

            indexed_buf[i / 3] = gop.value_ptr.*;
        }

        return .{
            .indexed = indexed_buf,
            .palette = palette_buf[0..next_index*3],
        };
    }
};

// PLTE Chunk contains the list of colors of the based image
const PLTE = struct {
    // must appear for color type 3, and can appear for color types 2 and 6;
    // it must not appear for color types 0 and 4.
    // If this chunk does appear, it must precede the first IDAT chunk.
    alloc: *const std.mem.Allocator,
    color_type: u8,
    bit_depth: u8,
    entries: []u8,


    pub fn create(alloc: std.mem.Allocator, color_type: u8, bit_depth: u8, quant: Quant) !PLTE {
        const num_entries = quant.palette.len / 3;

        if (num_entries == 0 or num_entries > 256) return error.InvalidPaletteSize;

        var entries = try alloc.alloc(u8, num_entries * 3);

        for (quant.palette, 0..) |_, i| {
            if (i %  3 == 0) {
                const j = i / 3;
                const r = quant.palette[i];
                const g = quant.palette[i+1];
                const b = quant.palette[i+2];

                entries[j * 3 + 0] = r;
                entries[j * 3 + 1] = g;
                entries[j * 3 + 2] = b;
            }
        }

        return .{
            .alloc = &alloc,
            .color_type = color_type,
            .bit_depth = bit_depth,
            .entries = entries,
        };
    }

    pub fn deinit(self: PLTE) void {
        self.alloc.free(self.entries);
    }

    pub fn set_palettes(self: PLTE) void {
        _ = self;
        //TODO:
        //https://libpng.org/pub/png/spec/1.2/PNG-Encoders.html#E.Suggested-palettes
        return;
    }

    // Color Type 3 (indexed color):
    // First entry is referenced by pixel value 0, the second by pixel value 1
    pub fn set_indexed_color() void {
        return;
    }

    // Color type 2 and 6 (ture color):
    // Suggested-palettes from 1 to 256
    // Recomended encoder: 
    // https://libpng.org/pub/png/spec/1.2/PNG-Encoders.html#E.Suggested-palettes
    pub fn set_true_color_with_alpha() void {
        return;
    }


    pub fn set_entry(self: *PLTE, i: usize, r: u8, g: u8, b: u8) !void {
        if (i >= self.entries.len / 3) return error.IndexOutOfRange;
        self.entries[i * 3 + 0] = r;
        self.entries[i * 3 + 1] = g;
        self.entries[i * 3 + 2] = b;
    }

    pub fn to_byte_array(self: PLTE) []u8 {
        return self.entries;
    }

    pub fn to_chunk(self: PLTE) Chunk {
        return Chunk.create(.{ 'P', 'L', 'T', 'E' }, self.to_byte_array());
    }
};

// https://libpng.org/pub/png/spec/1.2/PNG-Chunks.html
// IDAT Chunk contains the actual iamge data 
const IDAT = struct {

    alloc: std.mem.Allocator,
    data: []u8,

    pub fn create(alloc: std.mem.Allocator, data: []u8) IDAT  {
        return .{
            .alloc = alloc,
            .data = data
        };
    }

};

// The IEND chunk marks the end of the PNG datastream
// Its must appear at the end of the file
// its an empty chunk
const IEND = struct {

    alloc: std.mem.Allocator,

    pub fn create(alloc: std.mem.Allocator) IEND {
        return .{
            .alloc = alloc,
        };
    }

    pub fn to_chunk(self: IEND) Chunk {
        _ = self;
        return Chunk.create(.{'I','E', 'N', 'D'}, &[0]u8{});
    }
};
