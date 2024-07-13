const std = @import("std");
const SDL = @import("sdl2");
const View = @import("../view.zig").View;
const Operation = @import("../operation.zig");
const SDLex = @import("../SDLex.zig");
const design = @import("../design.zig").heap;
const ZoomAnimation = @import("../animation.zig").ZoomAnimation;
pub var gpa = std.heap.GeneralPurposeAllocator(.{}){};
pub const rows = 50;
pub const columns = 50;
const Ownership = enum(u8) {
    free, //block is available for alocation.
    taken, // block used by another program.
    user, // allocated by user and can be used.

};
const block = struct {
    val: i64,
    owner: Ownership,
};

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

pub var mem: [rows * columns]block = undefined;
// a copy that is nodified on fuction calls from the user instead of by operation
pub var mem_runtime: [rows * columns]block = undefined;

//initiallize heap with random values in range 0 - 999;
pub fn initRand() void {
    //initiallize values
    const time: usize = @intCast(std.time.timestamp());
    for (&mem, 0..) |*blk, idx| {
        const random_neg: i64 = @rem(randomNum(@intCast(time + idx)), 10000); // always positive
        const random_pos: i64 = @rem(randomNum(@intCast((time + idx) * 2)), 10000) * -1; // always negative
        blk.val = @intCast(random_neg + random_pos);
    }
    initAvailability();
    @memcpy(mem_runtime[0..], mem[0..]);
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
    for (&mem, 0..) |*blk, idx| {
        blk.owner = if (cur_val_set) Ownership.taken else Ownership.free;

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
var batches_to_update: std.AutoHashMap(idx2D, void) = undefined;
pub fn initTextures(renderer: SDL.Renderer) !void {
    for (0..batch_tex.len) |row| {
        for (0..batch_tex[0].len) |column| {
            try initBatch(.{ .y = row, .x = column }, renderer);
        }
    }
    batches_to_update = std.AutoHashMap(idx2D, void).init(gpa.allocator());
}

fn initBatch(index: idx2D, renderer: SDL.Renderer) !void {
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

            const num_str = std.fmt.bufPrintZ(&text_buffer, "{d:>5}", .{mem[idx1].val}) catch "???";
            // color tuning
            const color_fg: SDL.Color = switch (mem[idx1].owner) {
                .free => design.block.free.fg,
                .taken => design.block.taken.fg,
                .user => design.block.user.fg,
            };
            const color_bg: SDL.Color = switch (mem[idx1].owner) {
                .free => design.block.free.bg,
                .taken => design.block.taken.bg,
                .user => design.block.user.bg,
            };

            surf = design.font.renderTextBlended(num_str, color_fg) catch handle: {
                std.debug.print("failed to load surface for texture\npossible used bad font.\n", .{});
                break :handle try SDL.createRgbSurfaceWithFormat(32, 32, SDL.PixelFormatEnum.rgba8888);
            };
            const texture = try SDL.createTextureFromSurface(renderer, surf);
            var block_rect = SDLex.convertSDLRect(blockRect(idx1));
            block_rect.x -= @intCast(index.x * batch_size.width * design.block.full_size.width + 1);
            block_rect.y -= @intCast(index.y * batch_size.height * design.block.full_size.height + 1);

            try renderer.setColor(color_bg);
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
    const max_width = design.block.full_size.width * columns;
    const max_height = design.block.full_size.height * rows;

    try renderer.setColor(design.block.grid_color);
    for (0..batch_size.height + 1) |row| {
        var rect = SDL.Rectangle{
            .x = 0,
            .y = @intCast(@as(c_int, @intCast(row * design.block.full_size.height)) - design.block.padding.height / 4),
            .width = @intCast(design.block.full_size.width * batch_size.width + design.block.padding.width),
            .height = design.block.padding.height / 2,
        };

        //prevent grid drawing on empty texture
        const chunck_limit_width = max_width - batch_size.width * design.block.full_size.width * index.x;
        const chunck_limit_height = max_height - batch_size.height * design.block.full_size.height * index.y;
        rect.width = @intCast(@min(chunck_limit_width, @as(usize, @intCast(rect.width))));

        if (chunck_limit_height > rect.y)
            try renderer.fillRect(rect);
    }

    for (0..batch_size.width + 1) |column| {
        var rect = SDL.Rectangle{
            .y = 0,
            .x = @intCast(@as(c_int, @intCast(column * design.block.full_size.width)) - design.block.padding.width / 4),
            .height = @intCast(design.block.full_size.height * batch_size.height + design.block.padding.height),
            .width = design.block.padding.width / 2,
        };
        //prevent grid drawing on empty texture
        const chunck_limit_width = max_width - batch_size.width * design.block.full_size.width * index.x;
        const chunck_limit_height = max_height - batch_size.height * design.block.full_size.height * index.y;
        rect.height = @intCast(@min(chunck_limit_height, @as(usize, @intCast(rect.height))));

        if (rect.x < chunck_limit_width)
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
    batches_to_update.deinit();
}

pub fn draw(renderer: SDL.Renderer, view: View) void {
    //updates the batches that has changed
    if (batches_to_update.count() > 0) {
        var it = batches_to_update.keyIterator();
        while (it.next()) |batch| {
            batch_tex[batch.y][batch.x].destroy();
            initBatch(batch.*, renderer) catch unreachable;
        }
        batches_to_update.clearRetainingCapacity();
    }
    //drawing
    for (0..batch_tex.len) |row| {
        for (0..batch_tex[0].len) |column| {
            drawBatch(.{ .y = row, .x = column }, renderer, view);
        }
    }
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
    if (idx >= mem.len) {
        return HeapError.OutOfRange;
    }
    return if (mem_runtime[idx].owner == .user)
        mem_runtime[idx].val
    else
        HeapError.MemoryNotAllocated;
}

pub fn setBG(color: SDL.Color) void {
    Operation.push(Operation.Operation{ .change_bg = color });
}

pub fn set(idx: usize, value: i64, renderer: SDL.Renderer) !void {
    if (idx >= mem.len)
        return HeapError.OutOfRange;
    if (mem[idx].owner == Ownership.user) {
        mem[idx].val = value;
    } else {
        return HeapError.MemoryNotAllocated;
    }

    //recreate texture of the batch containing the value.
    const owning_batch = batchOf(idx);
    try batches_to_update.put(owning_batch, {});
    try initBatch(owning_batch, renderer);
}
pub fn allocate(idx: usize) HeapError!void {
    if (mem[idx].owner != Ownership.free) {
        return HeapError.MemoryNotAvailable;
    }
    mem[idx].owner = Ownership.user;
    batches_to_update.put(batchOf(idx), {}) catch unreachable;
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

pub fn findFreeRange(size: usize) HeapError!struct { start: usize, end: usize } {
    var start_idx: usize = 0;
    var end_idx: usize = 0;
    var found: bool = false;

    main: for (0..mem.len - size) |Sidx| {
        if (mem[Sidx].owner != .free) continue;

        for (Sidx..mem.len) |Eidx| {
            if (mem_runtime[Eidx].owner != .free)
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

//---------------------------------------------------
//---------------------------------------------------
//---------------------TESTING-----------------------
//---------------------------------------------------
//---------------------------------------------------

test "idx2d" {
    const idx = 69;
    const cols = 50;
    const idx2d = idx2D.init(idx, cols);
    try std.testing.expect(idx2d.x == 19 and idx2d.y == 1);
    try std.testing.expect(idx2d.to1D(cols) == idx);
}

test "freerange" {
    const range_67 = findFreeRange(67);
    if (range_67) |rng| {
        try std.testing.expect(rng.end - rng.start == 67);
    } else |_| {
        std.debug.print("could not find range.", .{});
    }
    const range_13 = findFreeRange(13);
    if (range_13) |rng| {
        try std.testing.expect(rng.end - rng.start == 13);
    } else |_| {
        std.debug.print("could not find range.", .{});
    }
}
