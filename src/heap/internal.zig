const std = @import("std");
const SDL = @import("sdl2");
const View = @import("../view.zig").View;
const Operation = @import("../operation.zig");
const SDLex = @import("../SDLex.zig");
const design = @import("../design.zig").heap;
const ZoomAnimation = @import("../animation.zig").ZoomAnimation;
const gpa = std.heap.GeneralPurposeAllocator(.{}){};
pub const rows = 100;
pub const columns = 100;
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
        availables[idx] = cur_val_set;

        //flip value on random occasion
        if (@rem(randomNum(@intCast(time + idx)), columns) == 1)
            cur_val_set = !cur_val_set;
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

    batch_tex[index.y][index.x] =
        try SDL.createTexture(renderer, SDL.Texture.Format.rgba8888, .target, design.block.full_size.width * batch_size.width, design.block.full_size.height * batch_size.height);
    try batch_tex[index.y][index.x].setBlendMode(SDL.BlendMode.blend);
    try renderer.setTarget(batch_tex[index.y][index.x]);

    //memory section to use based on batch_index
    const mem_start: idx2D = .{ .x = @intCast(batch_size.width * index.x), .y = @intCast(batch_size.height * index.y) };
    const original_renderer_color = try SDL.Renderer.getColor(renderer);
    for (mem_start.y..mem_start.y + batch_size.height) |row| {
        for (mem_start.x..mem_start.x + batch_size.width) |column| {
            const idx2 = idx2D{ .x = column, .y = row };
            const idx1 = idx2.to1D(columns);
            //skip cases outside memory bounds
            if (row >= rows or column >= columns)
                continue;

            const num_str = std.fmt.bufPrintZ(&text_buffer, "{d:>5}", .{mem[idx1]}) catch "???";
            const color: SDL.Color = if (availables[idx1]) design.block.free.fg else design.block.taken.fg;
            surf = font.renderTextBlended(num_str, color) catch handle: {
                std.debug.print("failed to load surface for texture\npossible used bad font.\n", .{});
                break :handle try SDL.createRgbSurfaceWithFormat(32, 32, SDL.PixelFormatEnum.rgb888);
            };
            const texture = try SDL.createTextureFromSurface(renderer, surf);
            var block_rect = SDLex.convertSDLRect(blockRect(idx1));
            block_rect.x -= @intCast(index.x * batch_size.width * design.block.full_size.width + 1);
            block_rect.y -= @intCast(index.y * batch_size.height * design.block.full_size.height + 1);

            //std.debug.print("block rect: {d},{d},{d},{d}\n", block_rect);
            try renderer.setColor(if (availables[idx1]) design.block.free.bg else design.block.taken.bg);
            try renderer.fillRect(block_rect);
            block_rect.x += design.block.padding.width / 2;
            block_rect.y += design.block.padding.height / 2;
            block_rect.width = design.block.size.width;
            block_rect.height = design.block.size.height;

            try renderer.copy(texture, block_rect, null);
            surf.destroy();
            texture.destroy();
        }
    }
    //draw grid:
    try renderer.setColor(design.block.grid_color);
    for (0..batch_size.height + 1) |row| {
        const rect = SDL.Rectangle{
            .x = 0,
            .y = @intCast(@as(c_int, @intCast(row * design.block.full_size.height)) - design.block.padding.height / 4),
            .width = @intCast(design.block.full_size.width * batch_size.width + design.block.padding.width),
            .height = design.block.padding.height / 2,
        };

        try renderer.fillRect(rect);
    }
    for (0..batch_size.width + 1) |column| {
        const rect = SDL.Rectangle{
            .y = 0,
            .x = @intCast(@as(c_int, @intCast(column * design.block.full_size.width)) - design.block.padding.width / 4),
            .height = @intCast(design.block.full_size.height * batch_size.height + design.block.padding.height),
            .width = design.block.padding.width / 2,
        };

        try renderer.fillRect(rect);
    }
    try renderer.setColor(original_renderer_color);
    try renderer.setTarget(last_target);
}

pub fn destroyTextures() void {
    for (batch_tex) |row| {
        for (row) |column| {
            column.destroy();
        }
    }
}

pub fn draw(renderer: SDL.Renderer, view: View) void {
    for (0..batch_tex.len) |row| {
        for (0..batch_tex[0].len) |column| {
            drawBatch(.{ .y = row, .x = column }, renderer, view);
        }
    }

    const save_color = renderer.getColor() catch unreachable;
    renderer.setColor(design.block.grid_color) catch unreachable;

    renderer.setColor(save_color) catch unreachable;
}

pub fn drawBatch(idx: idx2D, renderer: SDL.Renderer, view: View) void {
    const batch_rect = SDL.RectangleF{
        .x = @floatFromInt(idx.x * design.block.full_size.width * batch_size.width),
        .y = @floatFromInt(idx.y * design.block.full_size.height * batch_size.height),
        .width = @floatFromInt((design.block.full_size.width) * batch_size.width),
        .height = @floatFromInt((design.block.full_size.height) * batch_size.height),
    };
    var converted_rect = SDLex.convertSDLRect(view.convert(batch_rect) catch return);
    converted_rect.width += 1;
    converted_rect.height += 1;
    renderer.copy(batch_tex[idx.y][idx.x], converted_rect, null) catch unreachable;
}

//---------------------------------------------------
//---------------------------------------------------
//-------------------INTERFACE-----------------------
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

pub fn setBG(color: SDL.Color) void {
    Operation.push(Operation.Operation{ .change_bg = color });
}

pub fn set(idx: usize, value: i64, renderer: SDL.Renderer) !void {
    if (idx >= mem.len)
        return HeapError.OutOfRange;
    mem[idx] = value;
    //recreate texture of the batch containing the value.
    const owning_batch = batchOf(idx);
    batch_tex[owning_batch.y][owning_batch.x].destroy();
    try initBatch(owning_batch, &design.font, renderer);
}
pub fn alloc(size: usize) HeapError![]const i64 {
    const range = try findFreeRange(size);
    return mem[range.start..range.end];
}

//---------------------------------------------------
//---------------------------------------------------
//---------------------HELPERS-----------------------
//---------------------------------------------------
//---------------------------------------------------
fn randomNum(seed: i64) i64 {
    const state: i64 = seed * 747796405 + 2891336453;
    const word: i64 = ((state >> @as(u6, @truncate(@as(u64, @intCast(state)) >> 28)) +% 4) ^ state) *% 277803737;
    return (word >> 22) ^ word;
}

//---------------------------------------------------
//---------------------------------------------------
//--------------INTERNAL ABSTRACTIONS----------------
//---------------------------------------------------
//---------------------------------------------------

fn batchOf(mem_idx: usize) idx2D {
    const idx_2d: idx2D = idx2D.init(mem_idx, columns);
    return .{ .x = @divFloor(idx_2d.x, batch_size.width), .y = @divFloor(idx_2d.y, batch_size.height) };
}

pub fn blockRect(block_idx: usize) SDL.RectangleF {
    const idx_2d = idx2D.init(block_idx, columns);
    const rect = SDL.Rectangle{
        .x = @intCast(design.position.x + @as(c_int, @intCast(idx_2d.x)) * design.block.full_size.width),
        .y = @intCast(design.position.y + idx_2d.y * design.block.full_size.height),
        .width = @intCast(design.block.full_size.width),
        .height = @intCast(design.block.full_size.height),
    };
    return SDLex.convertSDLRect(rect);
}

fn findFreeRange(size: usize) HeapError!struct { start: usize, end: usize } {
    var start_idx: usize = 0;
    var end_idx: usize = 0;
    var found: bool = false;
    //var follow_animation = ZoomAnimation.init(cam_view.port, .{ .x = -500, .y = -500,.width = 1000,.height = 1000 }, 500_000_000);

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
    return .{ .start = start_idx, .end = end_idx };
}
