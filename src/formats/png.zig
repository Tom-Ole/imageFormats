// see: https://libpng.org/pub/png/spec/1.2/PNG-Rationale.html#R.PNG-file-signature

const std = @import("std");
const utils = @import("utils");
const u32le = utils.u32le;
const u16le = utils.u16le;

const Self = @This();

header: Header,

pub fn create() Self {
    return .{
        .header = Header.create(),
    };
}

const Header = struct {
    signiture: [8]u8,
    ihdr: Chunk,

    pub fn create() Header {
        const signiture: [8]u8 = .{ 0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a }; // ASCII: \211   P   N   G  \r  \n \032 \n
        const _IHDR = Chunk.create(.{ 'I', 'H', 'D', 'R' }, IHDR.create().to_byte_array());

        return .{ .signiture = signiture, .ihdr = _IHDR };
    }
};

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
    crc: [4]u8,

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
    compresion_method: u8,
    filter_method: u8,
    interlace_method: u8,

    pub fn create(width: u32, height: u32, bit_depth: u8, color_type: u8, compresion_method: u8, filter_method: u8, interlace_method: u8) IHDR {
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

    pub fn to_byte_array(self: IHDR) [13]u8 {
        const alloc = std.heap.page_allocator;
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
};
