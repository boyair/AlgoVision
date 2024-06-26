const std = @import("std");
const SDL = @import("sdl2");
pub const rows = 64;
pub const columns = 64;
pub const size = rows * columns;

pub var mem: [rows][columns]i64 = undefined;
pub var availables: [size]bool = undefined;

//initiallize heap with random values in range 0 - 999;
pub fn initRand() void {
    //initiallize values
    const time: usize = @intCast(std.time.timestamp());
    for (0..mem.len) |row| {
        for (0..mem[0].len) |column| {
            const random_neg: i64 = @rem(randomNum(@intCast(row * column + time)), 10000); // always positive
            const random_pos: i64 = @rem(randomNum(@intCast((row * column + time) * 2)), 10000) * -1; // always negative
            mem[row][column] = random_neg + random_pos;
        }
    }

    //set availability
    var cur_idx: u64 = 1;
    var last_idx: u64 = 0;
    var set: bool = true;
    while (cur_idx < availables.len) {
        std.debug.print("other round. {d}", .{cur_idx});
        last_idx = cur_idx;
        cur_idx += @intCast(@rem(randomNum(@intCast(time + last_idx)), rows * 2) + 3);
        if (cur_idx >= availables.len) {
            for (last_idx..availables.len) |i| {
                availables[i] = set;
            }
            break;
        }
        set = !set;
        for (last_idx..cur_idx) |i| {
            availables[i] = set;
        }
    }
}
const batch_size: SDL.Size = .{ .width = std.math.sqrt(rows), .height = std.math.sqrt(columns) };

pub var batch_tex: [rows / batch_size.width][columns / batch_size.height]SDL.Texture = undefined; // textures of the numbers batched intp groups for performance
pub var mem_tex: [mem.len]SDL.Texture = undefined; // textures of the numbers batched intp groups for performance
pub fn initTextures(font: *const SDL.ttf.Font, renderer: SDL.Renderer) !void {
    std.debug.print("{d}", .{mem.len});
    var surf: SDL.Surface = undefined;
    var buf: [12]u8 = undefined;
    batch_tex[0][0] = SDL.createTexture(renderer, SDL.Texture.Format.bgr888, .static, batch_size.width * 100, batch_size.height * 100);

    for (0..batch_size.height) |row| {
        for (0..batch_size.width) |column| {
            const current = *mem[row * columns + column];
            const num_str = std.fmt.bufPrintZ(&buf, "{d:>4}", .{current.*}) catch "???";
            const color: SDL.Color = if (availables[idx]) SDL.Color.white else SDL.Color.red;
            surf = font.renderTextSolid(num_str, color) catch handle: {
                std.debug.print("failed to load surface for texture {d}\npossible used bad font.\n", .{idx});
                break :handle try SDL.createRgbSurfaceWithFormat(32, 32, SDL.PixelFormatEnum.rgb888);
            };
            mem_tex[idx] = try SDL.createTextureFromSurface(renderer, surf);
        }
    }
}
pub fn destroyTextures() void {
    for (mem_tex) |tex| {
        tex.destroy();
    }
}

fn randomNum(seed: i64) i64 {
    const state: i64 = seed * 747796405 + 2891336453;
    const word: i64 = ((state >> @as(u6, @truncate(@as(u64, @intCast(state)) >> 28)) +% 4) ^ state) *% 277803737;
    return (word >> 22) ^ word;
}
