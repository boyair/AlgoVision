const std = @import("std");
const SDL = @import("sdl2");
pub const rows = 64;
pub const columns = 64;
//struct to simplify 2d indexing
const idx2D = struct {
    x: usize = 0, //2nd index
    y: usize = 0, //1st index
    pub fn to1D(self: idx2D, row_length: usize) usize {
        return self.y * row_length + self.x;
    }
};

pub var mem: [rows][columns]i64 = undefined;
pub var availables: [rows][columns]bool = undefined;

//initiallize heap with random values in range 0 - 999;
pub fn initRand() void {
    //initiallize values
    const time: usize = @intCast(std.time.timestamp());
    for (0..mem.len) |row| {
        for (0..mem[0].len) |column| {
            const random_neg: i64 = @rem(randomNum(@intCast(time + row * columns + column)), 10000); // always positive
            const random_pos: i64 = @rem(randomNum(@intCast((time + row * columns + column) * 2)), 10000) * -1; // always negative
            mem[row][column] = @intCast(random_neg + random_pos);
        }
    }
    initAvailability();
}

//initiallize heap such that each block gets its ondex value;
pub fn initIndex() void {
    //initiallize values
    for (0..mem.len) |row| {
        for (0..mem[0].len) |column| {
            mem[row][column] = @intCast(idx2D.to1D(.{ .x = column, .y = row }, columns));
        }
    }
    initAvailability();
}
fn initAvailability() void {
    const time: usize = @intCast(std.time.timestamp());
    var cur_val_set = false;
    for (0..availables.len) |row| {
        for (0..availables[0].len) |column| {
            availables[row][column] = cur_val_set;

            //flip value on random occasion
            if (@rem(randomNum(@intCast(time + row * columns + column)), columns) == 1)
                cur_val_set = !cur_val_set;
        }
    }
}

//---------------------------------------------------
//---------------------------------------------------
//----------------TEXTURE HANDLING-------------------
//---------------------------------------------------
//---------------------------------------------------

const batch_size: SDL.Size = .{ .width = std.math.sqrt(rows), .height = std.math.sqrt(columns) };
pub var batch_tex: [rows / batch_size.width + 1][columns / batch_size.height + 1]SDL.Texture = undefined; // textures of the numbers batched for performance

pub fn initTextures(font: *const SDL.ttf.Font, renderer: SDL.Renderer) !void {
    for (0..batch_tex.len) |row| {
        for (0..batch_tex[0].len) |column| {
            try initBatch(.{ .y = row, .x = column }, font, renderer);
        }
    }
}

pub fn initBatch(index: idx2D, font: *const SDL.ttf.Font, renderer: SDL.Renderer) !void {
    //make buffers for texture creation.
    var surf: SDL.Surface = undefined;
    var text_buffer: [12]u8 = undefined;

    //initiallize texture to draw on
    const last_target = renderer.getTarget();
    batch_tex[index.y][index.x] =
        try SDL.createTexture(renderer, SDL.Texture.Format.bgr888, .target, batch_size.width * 100, batch_size.height * 100);
    try renderer.setTarget(batch_tex[index.y][index.x]);
    try renderer.clear(); // make the background same as renderer color.

    //memory section to use based on batch_index
    const mem_start: idx2D = .{ .x = @intCast(batch_size.width * index.x), .y = @intCast(batch_size.height * index.y) };

    for (mem_start.y..mem_start.y + batch_size.height) |row| {
        for (mem_start.x..mem_start.x + batch_size.width) |column| {
            //skip cases outside memory boundsk
            if (row >= mem.len or column >= mem[0].len)
                continue;

            const num_str = std.fmt.bufPrintZ(&text_buffer, "{d:>4}", .{mem[row][column]}) catch "???";
            const color: SDL.Color = if (availables[row][column]) SDL.Color.white else SDL.Color.red;
            surf = font.renderTextSolid(num_str, color) catch handle: {
                std.debug.print("failed to load surface for texture\npossible used bad font.\n", .{});
                break :handle try SDL.createRgbSurfaceWithFormat(32, 32, SDL.PixelFormatEnum.rgb888);
            };
            const texture = try SDL.createTextureFromSurface(renderer, surf);
            try renderer.copy(texture, .{ .x = @intCast(100 * (column - mem_start.x)), .y = @intCast(100 * (row - mem_start.y)), .width = 100, .height = 100 }, null);
            surf.destroy();
            texture.destroy();
        }
    }
    try renderer.setTarget(last_target);
}

pub fn destroyTextures() void {
    for (batch_tex) |row| {
        for (row) |column| {
            column.destroy();
        }
    }
}

fn randomNum(seed: i64) i64 {
    const state: i64 = seed * 747796405 + 2891336453;
    const word: i64 = ((state >> @as(u6, @truncate(@as(u64, @intCast(state)) >> 28)) +% 4) ^ state) *% 277803737;
    return (word >> 22) ^ word;
}
