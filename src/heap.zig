const std = @import("std");
const View = @import("view.zig").View;
const SDL = @import("sdl2");
const SDLex = @import("SDLex.zig");
const design = @import("design.zig").heap;
pub const rows = 10;
pub const columns = 10;
//struct to simplify 2d indexing
const idx2D = struct {
    x: usize = 0, //2nd index
    y: usize = 0, //1st index
    pub fn init(idx1D: usize, row_length: usize) idx2D {
        return .{
            .x = idx1D % row_length,
            .y = idx1D / row_length,
        };
    }
    pub fn to1D(self: idx2D, row_length: usize) usize {
        return self.y * row_length + self.x;
    }
};
const HeapError = error{
    OutOfRange,
    MemoryNotAvailable,
    MemoryNotAllocated,
};

pub var mem: [rows * columns]i64 = undefined;
pub var availables: [mem.len]bool = undefined;

//initiallize heap with random values in range 0 - 999;
pub fn initRand() void {
    //initiallize values
    const time: usize = @intCast(std.time.timestamp());
    for (0..mem.len) |idx| {
        const random_neg: i64 = @rem(randomNum(@intCast(time + idx)), 10000); // always positive
        const random_pos: i64 = @rem(randomNum(@intCast((time + idx) * 2)), 10000) * -1; // always negative
        mem[idx] = @intCast(random_neg + random_pos);
    }
    initAvailability();
}

//initiallize heap such that each block gets its ondex value;
pub fn initIndex() void {
    //initiallize values
    for (0..mem.len) |idx| {
        mem[idx] = @intCast(idx);
    }
    initAvailability();
}
fn initAvailability() void {
    const time: usize = @intCast(std.time.timestamp());
    var cur_val_set = false;
    for (0..availables.len) |idx| {
        availables[idx] = false;

        //flip value on random occasion
        if (@rem(randomNum(@intCast(time + idx)), columns) == 1)
            cur_val_set = !cur_val_set;
    }
    //test
    for (4..10) |i| {
        availables[i] = true;
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

fn initBatch(index: idx2D, font: *const SDL.ttf.Font, renderer: SDL.Renderer) !void {
    //make buffers for texture creation.
    var surf: SDL.Surface = undefined;
    var text_buffer: [12]u8 = undefined;

    //initiallize texture to draw on
    const last_target = renderer.getTarget();

    const final_block_size =
        .{
        .width = @as(usize, batch_size.width * (design.block_size.width + design.padding_size.width)),
        .height = @as(usize, batch_size.height * (design.block_size.height + design.padding_size.height)),
    };
    batch_tex[index.y][index.x] =
        try SDL.createTexture(renderer, SDL.Texture.Format.rgba8888, .target, final_block_size.width, final_block_size.height);
    try batch_tex[index.y][index.x].setBlendMode(SDL.BlendMode.blend);
    try renderer.setTarget(batch_tex[index.y][index.x]);

    //memory section to use based on batch_index
    const mem_start: idx2D = .{ .x = @intCast(batch_size.width * index.x), .y = @intCast(batch_size.height * index.y) };

    for (mem_start.y..mem_start.y + batch_size.height) |row| {
        for (mem_start.x..mem_start.x + batch_size.width) |column| {
            const idx2 = idx2D{ .x = column, .y = row };
            const idx1 = idx2.to1D(columns);
            //skip cases outside memory bounds
            if (row >= rows or column >= columns)
                continue;

            const num_str = std.fmt.bufPrintZ(&text_buffer, "{d:>4}", .{mem[idx1]}) catch "???";
            const color: SDL.Color = if (availables[idx1]) SDL.Color.white else SDL.Color.red;
            surf = font.renderTextBlended(num_str, color) catch handle: {
                std.debug.print("failed to load surface for texture\npossible used bad font.\n", .{});
                break :handle try SDL.createRgbSurfaceWithFormat(32, 32, SDL.PixelFormatEnum.rgb888);
            };
            const texture = try SDL.createTextureFromSurface(renderer, surf);
            try renderer.copy(texture, .{ .x = @intCast((design.padding_size.width + design.block_size.width) * (column - mem_start.x)), .y = @intCast((design.padding_size.height + design.block_size.height) * (row - mem_start.y)), .width = design.block_size.width, .height = design.block_size.height }, null);
            surf.destroy();
            texture.destroy();
        }
    }
    try renderer.setTarget(last_target);
}

pub fn alloc(size: usize) HeapError![]const i64 {
    var start_idx: usize = 0;
    var end_idx: usize = 0;
    var found: bool = false;
    main: for (0..(rows * columns)) |Sidx| {
        if (!availables[Sidx]) continue;

        for (Sidx..(rows * columns)) |Eidx| {
            if (!availables[Eidx])
                break;

            const true_end = Eidx + 1; // range is not inclusive
            if (size <= true_end - Sidx) {
                found = true;
                start_idx = Sidx;
                end_idx = true_end;
                break :main;
            }
        }
    }
    if (!found)
        return HeapError.MemoryNotAvailable;

    return mem[start_idx..end_idx];
}

pub fn destroyTextures() void {
    for (batch_tex) |row| {
        for (row) |column| {
            column.destroy();
        }
    }
}

pub fn draw(renderer: SDL.Renderer, view: View) void {
    const full_rect = SDL.Rectangle{
        .x = design.position.x - design.padding_size.width / 2,
        .y = design.position.y - design.padding_size.height / 2,
        .width = (design.block_size.width + design.padding_size.width) / 1 * columns,
        .height = (design.block_size.height + design.padding_size.height) / 1 * rows,
    };
    const save_color = renderer.getColor() catch unreachable;
    renderer.setColor(design.color_BG) catch unreachable;
    view.fillRect(SDLex.convertSDLRect(full_rect), renderer);
    renderer.setColor(save_color) catch unreachable;
    for (0..batch_tex.len) |row| {
        for (0..batch_tex[0].len) |column| {
            drawBatch(.{ .y = row, .x = column }, renderer, view);
        }
    }
}

pub fn drawBatch(idx: idx2D, renderer: SDL.Renderer, view: View) void {
    const batch_rect = SDL.RectangleF{
        .x = @floatFromInt(design.position.x + idx.x * (design.block_size.width + design.padding_size.width) * batch_size.width),
        .y = @floatFromInt(design.position.y + idx.y * (design.block_size.height + design.padding_size.height) * batch_size.height),
        .width = @floatFromInt((design.block_size.width + design.padding_size.width) * batch_size.width),
        .height = @floatFromInt((design.block_size.height + design.padding_size.height) * batch_size.height),
    };
    view.draw(batch_rect, batch_tex[idx.y][idx.x], renderer);
}

//---------------------------------------------------
//---------------------------------------------------
//---------------------HELPERS-----------------------
//---------------------------------------------------
//---------------------------------------------------

pub fn get(idx: usize) HeapError!i64 {
    if (idx >= mem.len * mem[0].len) {
        return HeapError.OutOfRange;
    }
    const mem_idx = idx2D.init(idx, mem[0].len);
    if (availables[mem_idx.y][mem_idx.x] == false) {
        return HeapError.MemoryNotAvailable;
    }
    return mem[mem_idx.y][mem_idx.x];
}

//pub fn set(value: i64, idx: usize) HeapError!void {
//    if (idx >= mem.len * mem[0].len) {
//        return HeapError.OutOfRange;
//    }
//    const mem_idx = idx2D.init(idx, mem[0].len);
//    if (availables[mem_idx.y][mem_idx.x] == false) {
//        return HeapError.MemoryNotAvailable;
//    }
//    mem[mem_idx.y][mem_idx.x] = value;
//
//    //recreate texture for containing batch.
//    const batch_idx = idx2D{.x = mem_idx.x / batch_size.width,.y = mem_idx.y / batch_size.height};
//    batch_tex[batch_idx.y][batch_idx.x].destroy();
//    initBatch(batch_idx, font , renderer);
//}

fn randomNum(seed: i64) i64 {
    const state: i64 = seed * 747796405 + 2891336453;
    const word: i64 = ((state >> @as(u6, @truncate(@as(u64, @intCast(state)) >> 28)) +% 4) ^ state) *% 277803737;
    return (word >> 22) ^ word;
}
