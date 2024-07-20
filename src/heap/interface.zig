const std = @import("std");
const app = @import("../app.zig");
const SDL = @import("sdl2");
const Internals = @import("internal.zig");
const View = @import("../view.zig").View;
const Operation = @import("../operation.zig");
const SDLex = @import("../SDLex.zig");
const design = @import("../design.zig").heap;
const Vec2 = @import("../Vec2.zig").Vec2;
const ZoomAnimation = @import("../animation.zig").ZoomAnimation;

fn blockView(idx: usize) SDL.RectangleF {
    var block_view = Internals.blockRect(idx);
    block_view.x -= design.block.full_size.width * 4;
    block_view.y -= design.block.full_size.height * 4;
    block_view.width += design.block.full_size.width * 8;
    block_view.height += design.block.full_size.height * 8;
    return block_view;
}

fn rangeView(start: usize, end: usize) !SDL.RectangleF {
    const start_rect: SDL.RectangleF = Internals.blockRect(start);
    var min_x = start_rect.x;
    var min_y = start_rect.y;
    var max_x = start_rect.x;
    var max_y = start_rect.y;
    // find the the nearest view port points for full memory visibility
    for (start..end) |idx| {
        const block_rect = Internals.blockRect(idx);
        min_x = @min(min_x, block_rect.x);
        min_y = @min(min_y, block_rect.y);
        max_x = @max(max_x, block_rect.x + block_rect.width);
        max_y = @max(max_y, block_rect.y + block_rect.height);
    }
    //get edge length for square view
    const edge_length = @max(max_x - min_x, max_y - min_y);
    //get the center between min and max to make memory be in the enter instead of top left
    const center = Vec2.init((min_x + max_x) / 2, (min_y + max_y) / 2);
    var result = SDL.RectangleF{
        .x = center.x - edge_length / 2,
        .y = center.y - edge_length / 2,
        .width = edge_length,
        .height = edge_length,
    };
    //zooming out a bit to prevent allocated memory from being at the edge of the screen
    result.x -= design.block.full_size.width * 4;
    result.y -= design.block.full_size.height * 4;
    result.width += design.block.full_size.width * 8;
    result.height += design.block.full_size.height * 8;
    return result;
}

pub fn set(idx: usize, value: i64) void {
    const block_view = blockView(idx);
    const animation = ZoomAnimation.init(&app.cam_view, null, block_view, 200_000_000);

    const operation: Operation.Operation = .{ .animation = animation, .action = .{ .set_value_heap = .{ .idx = idx, .value = value } }, .pause_time_nano = 200_000_000 };
    Internals.mem_runtime[idx].val = value;

    app.operation_manager.push(operation);
}

pub fn get(idx: usize) i64 {
    return Internals.get(idx) catch |err| switch (err) {
        error.MemoryNotAllocated => {
            @panic("trying to get non allocated memory");
        },
        error.OutOfRange => {
            @panic("getting out of range index");
        },
        else => {
            @panic("failed to get value");
        },
    };
}

//return array (slice) of indices of allocated memory.
pub fn allocate(allocator: std.mem.Allocator, size: usize) []usize {
    const range = Internals.findFreeRange(size) catch {
        @panic("could not find large enough buffer");
    };

    for (0..range.start) |idx| {
        const block_view = blockView(idx);
        const animation = ZoomAnimation.init(&app.cam_view, null, block_view, 200_000_000);
        const operation: Operation.Operation = .{ .animation = animation, .action = .{ .search = {} }, .pause_time_nano = 200_000_000 };
        app.operation_manager.push(operation);
    }
    var indexes = std.ArrayList(usize).init(allocator);
    for (range.start..range.end) |idx| {
        Internals.mem_runtime[idx].owner = .user;
        indexes.append(idx) catch unreachable;
        const range_view = rangeView(range.start, idx + 1) catch unreachable;
        const animation = ZoomAnimation.init(&app.cam_view, null, range_view, 200_000_000);
        const operation: Operation.Operation = .{ .animation = animation, .action = .{ .allocate = idx }, .pause_time_nano = 200_000_000 };
        app.operation_manager.push(operation);
    }
    return indexes.toOwnedSlice() catch unreachable;
}

pub fn free(allocator: std.mem.Allocator, indices: []usize) void {
    for (indices) |idx| {
        if (Internals.mem_runtime[idx].owner == .user) {
            Internals.mem_runtime[idx].owner = .free;
            const animation = ZoomAnimation.init(&app.cam_view, null, blockView(idx), 200_000_000);
            const operation: Operation.Operation = .{ .animation = animation, .action = .{ .free = idx }, .pause_time_nano = 200_000_000 };
            app.operation_manager.push(operation);
        } else @panic("failed to free memory: not allocated");
    }
    allocator.free(indices);
}
