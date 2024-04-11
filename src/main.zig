const std = @import("std");
const print = std.debug.print;
const assert = std.debug.assert;

fn Image(comptime width: comptime_int, comptime height: comptime_int) type {
    assert(width != 0 and height != 0);
    return struct {
        width: usize,
        height: usize,
        data: [width * height]Pixel,
        use_colorful: bool,

        const Self = @This();
        pub fn init() Self {
            return .{ .use_colorful = false, .width = @as(usize, width), .height = @as(usize, height), .data = [_]Pixel{Pixel.new(0, 0, 0)} ** (width * height) };
        }

        pub fn print(self: *const Self, bw: *std.io.BufferedWriter(4096, std.fs.File.Writer)) !void {
            _ = try bw.write("+");
            for (0..self.width * 2 + 2) |_| {
                _ = try bw.write("-");
            }
            _ = try bw.write("+\n");
            for (0..self.height) |y| {
                _ = try bw.write("| ");
                for (0..self.width) |x| {
                    const data = self.data[x + y * self.width].to_str();
                    const data_array = [2]u8{ data, data };
                    _ = try bw.write(data_array[0..]);
                }
                _ = try bw.write(" | \n");
            }
            _ = try bw.write("+");
            for (0..self.width * 2 + 2) |_| {
                _ = try bw.write("-");
            }
            _ = try bw.write("+\n");

            try bw.flush();
        }

        pub fn spawn(self: *Self, rand: *xorshift32) Position {
            return while (true) {
                const random_index = rand.next() % self.data.len;
                if (!self.data[random_index].equals(&Pixel.new(0, 0, 0))) {
                    continue;
                } else {
                    const x = random_index % self.width;
                    const y = random_index / self.width;
                    self.data[random_index] = if (self.use_colorful) Pixel.new(
                        @truncate(rand.next()),
                        @truncate(rand.next()),
                        @truncate(rand.next()),
                    ) else Pixel.new(255, 255, 255);
                    break Position{ .x = x, .y = y };
                }
            };
        }

        pub fn is_full(self: *const Self) bool {
            for (&self.data) |*pix| {
                if (pix.equals(&Pixel.new(0, 0, 0))) return false;
            }
            return true;
        }

        pub fn percentage_full(self: *const Self) f32 {
            var counter: f32 = 0;
            for (&self.data) |*pix| {
                if (!pix.equals(&Pixel.new(0, 0, 0))) counter += 1;
            }

            return counter / @as(f32, @floatFromInt(self.width * self.height));
        }

        pub fn has_neighboring_colored_pixel(self: *const Self, pos: *const Position) bool {
            var off_x: isize = -1;
            while (off_x < 2) : (off_x += 1) {
                var off_y: isize = -1;
                while (off_y < 2) : (off_y += 1) {
                    if (off_x == 0 and off_y == 0) continue;
                    var i_x: isize = @as(isize, @intCast(pos.x)) + off_x;
                    var i_y: isize = @as(isize, @intCast(pos.y)) + off_y;
                    if (i_x < 0) i_x = @as(isize, @intCast(self.width)) - 1;
                    if (i_y < 0) i_y = @as(isize, @intCast(self.height)) - 1;
                    if (i_x >= self.width) i_x = 0;
                    if (i_y >= self.height) i_y = 0;

                    const new_x = @as(usize, @intCast(i_x));
                    const new_y = @as(usize, @intCast(i_y));

                    if (!self.data[new_x + new_y * self.width].equals(&Pixel.new(0, 0, 0))) return true;
                }
            }

            return false;
        }

        pub fn move_pixel_randomly(self: *Self, rand: *xorshift32, pos: *const Position) Position {
            const off_x = @mod(@as(isize, @intCast(rand.next())), 3) - 1;
            const off_y = @mod(@as(isize, @intCast(rand.next())), 3) - 1;

            var i_x: isize = @as(isize, @intCast(pos.x)) + off_x;
            var i_y: isize = @as(isize, @intCast(pos.y)) + off_y;
            if (i_x < 0) i_x = @as(isize, @intCast(self.width)) - 1;
            if (i_y < 0) i_y = @as(isize, @intCast(self.height)) - 1;
            if (i_x >= self.width) i_x = 0;
            if (i_y >= self.height) i_y = 0;

            const new_x = @as(usize, @intCast(i_x));
            const new_y = @as(usize, @intCast(i_y));
            std.mem.swap(Pixel, &self.data[new_x + new_y * self.width], &self.data[pos.x + pos.y * self.width]);
            return Position{ .x = new_x, .y = new_y };
        }

        /// https://stackoverflow.com/a/47785639
        // void generateBitmapImage (unsigned char* image, int height, int width, char* imageFileName)
        pub fn generate_bitmap_image(self: *const Self, file_idx: usize) !usize {

            // int widthInBytes = width * BYTES_PER_PIXEL;
            const width_in_bytes: u32 = @as(u32, @truncate(self.width)) * 3;

            // unsigned char padding[3] = {0, 0, 0};
            const padding = [3]u8{ 0, 0, 0 };
            // int paddingSize = (4 - (widthInBytes) % 4) % 4;
            const padding_size: u32 = @mod(4 - @mod(width_in_bytes, 4), 4);

            // int stride = (widthInBytes) + paddingSize;
            const stride: u32 = width_in_bytes + padding_size;

            // FILE* imageFile = fopen(imageFileName, "wb");
            std.fs.cwd().access("./images", .{}) catch {
                try std.fs.cwd().makeDir("./images");
            };
            var dir = try std.fs.cwd().openDir("./images", .{});
            defer dir.close();

            var buf: [14]u8 = .{0} ** 14;
            const file_name = try std.fmt.bufPrint(&buf, "image_{d:0>4}.bmp", .{file_idx});

            const file = try dir.createFile(file_name, .{});
            // fclose(imageFile);
            defer file.close();
            var bw = std.io.bufferedWriter(file.writer());

            var written_amount: usize = 0;

            // unsigned char* fileHeader = createBitmapFileHeader(height, stride);
            var header_buffer: [14]u8 = undefined;
            create_bitmap_file_header(&header_buffer, self.height, @as(usize, stride));
            // fwrite(fileHeader, 1, FILE_HEADER_SIZE, imageFile);
            written_amount += try bw.write(&header_buffer);

            // unsigned char* infoHeader = createBitmapInfoHeader(height, width);
            var info_buffer: [40]u8 = undefined;
            create_bitmap_info_header(&info_buffer, self.width, self.height);

            // fwrite(infoHeader, 1, INFO_HEADER_SIZE, imageFile);
            written_amount += try bw.write(&info_buffer);

            // int i;
            // for (i = 0; i < height; i++) {
            for (0..self.height) |y| {
                //     fwrite(image + (i*widthInBytes), BYTES_PER_PIXEL, width, imageFile);
                for (0..self.width) |x| {
                    const pix = &self.data[x + y * self.width];
                    const data = [3]u8{ pix.r, pix.g, pix.b };
                    written_amount += try bw.write(&data);
                }
                // fwrite(padding, 1, paddingSize, imageFile);
                written_amount += try bw.write(padding[0..padding_size]);
            }
            // }

            try bw.flush();
            return written_amount;
        }
    };
}

const xorshift32 = struct {
    x: u32,
    const Self = @This();

    pub fn next(self: *Self) u32 {
        var x = self.x;
        x ^= x >> 13;
        x ^= x << 17;
        x ^= x >> 5;
        self.x = x;
        return x;
    }
};

const Position = struct {
    x: usize,
    y: usize,
};

const Pixel = struct {
    r: u8,
    g: u8,
    b: u8,

    const Self = @This();

    pub fn new(r: u8, g: u8, b: u8) Self {
        return .{ .r = r, .g = g, .b = b };
    }

    pub fn to_str(self: *const Self) u8 {
        if (self.r == 255) {
            return '#';
        } else {
            return ' ';
        }
    }

    pub fn equals(lhs: *const Self, rhs: *const Self) bool {
        if (lhs.r != rhs.r) return false;
        if (lhs.g != rhs.g) return false;
        if (lhs.b != rhs.b) return false;
        return true;
    }
};

pub fn main() !void {
    var rand = xorshift32{ .x = 313121215 };
    print("Initialized xorshift32 with seed {}.\n", .{rand.x});

    const size = 90;
    // you can set these as whatever you want
    var canvas = Image(size, size).init();
    // set to false for black/white output
    canvas.use_colorful = true;
    print("Initialized {}x{} blank image.\n", .{ size, size });

    // initial pixel location. you can remove this and manually set a pixel location yourself
    _ = canvas.spawn(&rand);

    var i: usize = 0;
    while (canvas.percentage_full() < 0.18) {
        var new_position = canvas.spawn(&rand);
        while (!canvas.has_neighboring_colored_pixel(&new_position)) {
            new_position = canvas.move_pixel_randomly(&rand, &new_position);
        }

        // discard bytes written
        _ = try canvas.generate_bitmap_image(i);
        i += 1;
    }
}

/// https://stackoverflow.com/a/47785639
// unsigned char* createBitmapFileHeader (int height, int stride)
fn create_bitmap_file_header(buf: *[14]u8, h: usize, s: usize) void {
    const height: u32 = @truncate(h);
    const stride: u32 = @truncate(s);

    // int fileSize = FILE_HEADER_SIZE + INFO_HEADER_SIZE + (stride * height);
    const file_size: u32 = 14 + 40 + (stride * height);

    // static unsigned char fileHeader[] = {
    //     0,0,     /// signature
    //     0,0,0,0, /// image file size in bytes
    //     0,0,0,0, /// reserved
    //     0,0,0,0, /// start of pixel array
    // };
    for (0..14) |i| {
        buf.*[i] = 0;
    }

    // fileHeader[ 0] = (unsigned char)('B');
    buf.*[0] = 'B';
    // fileHeader[ 1] = (unsigned char)('M');
    buf.*[1] = 'M';
    // fileHeader[ 2] = (unsigned char)(fileSize      );
    // fileHeader[ 3] = (unsigned char)(fileSize >>  8);
    // fileHeader[ 4] = (unsigned char)(fileSize >> 16);
    // fileHeader[ 5] = (unsigned char)(fileSize >> 24);
    std.mem.writeInt(u32, buf.*[2..6], file_size, .little);
    // fileHeader[10] = (unsigned char)(FILE_HEADER_SIZE + INFO_HEADER_SIZE);
    buf.*[10] = 40 + 14;

    //     return fileHeader;
}

/// https://stackoverflow.com/a/47785639
// unsigned char* createBitmapInfoHeader (int height, int width)
fn create_bitmap_info_header(buf: *[40]u8, width: usize, height: usize) void {
    // static unsigned char infoHeader[] = {
    //     0,0,0,0, /// header size
    //     0,0,0,0, /// image width
    //     0,0,0,0, /// image height
    //     0,0,     /// number of color planes
    //     0,0,     /// bits per pixel
    //     0,0,0,0, /// compression
    //     0,0,0,0, /// image size
    //     0,0,0,0, /// horizontal resolution
    //     0,0,0,0, /// vertical resolution
    //     0,0,0,0, /// colors in color table
    //     0,0,0,0, /// important color count
    // };
    for (0..40) |i| {
        buf.*[i] = 0;
    }

    // infoHeader[ 0] = (unsigned char)(INFO_HEADER_SIZE);
    buf.*[0] = 40;
    // infoHeader[ 4] = (unsigned char)(width      );
    // infoHeader[ 5] = (unsigned char)(width >>  8);
    // infoHeader[ 6] = (unsigned char)(width >> 16);
    // infoHeader[ 7] = (unsigned char)(width >> 24);
    std.mem.writeInt(u32, buf.*[4..8], @truncate(width), .little);
    // infoHeader[ 8] = (unsigned char)(height      );
    // infoHeader[ 9] = (unsigned char)(height >>  8);
    // infoHeader[10] = (unsigned char)(height >> 16);
    // infoHeader[11] = (unsigned char)(height >> 24);
    std.mem.writeInt(u32, buf.*[8..12], @truncate(height), .little);
    // infoHeader[12] = (unsigned char)(1);
    buf.*[12] = 1;
    // infoHeader[14] = (unsigned char)(BYTES_PER_PIXEL*8);
    buf.*[14] = 24;

    // return infoHeader;
}
