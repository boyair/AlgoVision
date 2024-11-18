const std = @import("std");
const Pointer = @import("../pointer.zig");
const app = @import("../app.zig");
const SDL = @import("SDL");
const Internals = @import("internal.zig");
const View = @import("../view.zig").View;
const Operation = @import("../operation.zig");
const SDLex = @import("../SDLex.zig");
const design = @import("../design.zig").heap;
const Vec2 = @import("../Vec2.zig").Vec2;
const ZoomAnimation = @import("../animation.zig").ZoomAnimation;

//calculates camera rect to view a block on the heap
fn blockView(idx: usize) SDL.RectangleF {
    const view_size: SDL.Point = .{ .x = design.block.full_size.width * 9, .y = design.block.full_size.height * 9 };
    const block_view = Internals.blockRect(idx);
    return SDLex.alignedRect(block_view, .{ .x = 0.5, .y = 0.5 }, SDLex.conertVecPoint(view_size));
}

fn twoblockView(idx1: usize, idx2: usize) SDL.RectangleF {
    const rect1 = blockView(idx1);
    const rect2 = blockView(idx2);

    const min_x = @min(rect1.x, rect2.x);
    const min_y = @min(rect1.y, rect2.y);
    const max_x = @max(rect1.x + rect1.width, rect2.x + rect2.width);
    const max_y = @max(rect1.y + rect1.height, rect2.y + rect2.height);
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

//calculates camera rect to view a range on the heap
fn rangeView(start: usize, end: usize) SDL.RectangleF {
    const real_start = @min(start, end);
    const real_end = @max(start, end);

    const start_rect: SDL.RectangleF = Internals.blockRect(real_start);
    var min_x = start_rect.x;
    var min_y = start_rect.y;
    var max_x = start_rect.x;
    var max_y = start_rect.y;
    // find the the nearest view port points for full memory visibility
    for (real_start..real_end) |idx| {
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

pub fn setPointer(source: usize, destination: usize) void {
    if (Internals.mem_runtime[source].owner != .pointer and Internals.mem_runtime[source].owner != .user) @panic("tried to access non allocated memory ");
    if (Internals.mem_runtime[source].owner == .pointer) {
        const non_animation = ZoomAnimation.init(&app.cam_view, null, blockView(source), 0);
        const operation: Operation.Operation = .{ .animation = non_animation, .action = .{ .remove_pointer = .{ .source = .{ .heap = source }, .destination = null } }, .pause_time_nano = 0 };
        app.operation_manager.push(app.Allocator.allocator(), operation);
    }
    Internals.mem_runtime[source].val = @intCast(destination);
    Internals.mem_runtime[source].owner = .pointer;

    const pointer = Pointer.Pointer.init(true, source, destination);
    const animation = ZoomAnimation.init(&app.cam_view, blockView(source), twoblockView(source, destination), 400_000_000);
    const operation: Operation.Operation = .{ .animation = animation, .action = .{ .make_pointer = pointer }, .pause_time_nano = 300_000_000 };
    app.operation_manager.push(app.Allocator.allocator(), operation);
}

pub fn set(idx: usize, value: i64) void {
    const animation = ZoomAnimation.init(&app.cam_view, null, blockView(idx), 400_000_000);

    const operation: Operation.Operation = .{ .animation = animation, .action = .{ .set_value_heap = .{ .idx = idx, .value = value } }, .pause_time_nano = 300_000_000 };
    Internals.mem_runtime[idx].val = value;

    app.operation_manager.push(app.Allocator.allocator(), operation);
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
    const range = Internals.findRandFreeRange(size) catch {
        @panic("could not find large enough buffer");
    };
    var indices = std.ArrayList(usize).init(allocator);
    for (range.start..range.end) |idx| {
        Internals.mem_runtime[idx].owner = .user;
        indices.append(idx) catch unreachable;
        const range_view = rangeView(range.start, idx + 1);
        const animation = ZoomAnimation.init(&app.cam_view, null, range_view, 400_000_000);
        const operation: Operation.Operation = .{ .animation = animation, .action = .{ .allocate = idx }, .pause_time_nano = 300_000_000 };
        app.operation_manager.push(app.Allocator.allocator(), operation);
    }
    return indices.toOwnedSlice() catch unreachable;
}

pub fn free(allocator: std.mem.Allocator, indices: []usize) void {
    for (indices) |idx| {
        if (Internals.mem_runtime[idx].owner == .user or Internals.mem_runtime[idx].owner == .pointer) {
            if (Internals.mem_runtime[idx].owner == .pointer) {
                const non_animation = ZoomAnimation.init(&app.cam_view, null, blockView(idx), 0);
                const operation: Operation.Operation = .{ .animation = non_animation, .action = .{ .remove_pointer = .{ .source = .{ .heap = idx }, .destination = null } }, .pause_time_nano = 0 };
                app.operation_manager.push(app.Allocator.allocator(), operation);
            }

            Internals.mem_runtime[idx].owner = .free;
            const animation = ZoomAnimation.init(&app.cam_view, null, blockView(idx), 400_000_000);

            const operation: Operation.Operation = .{ .animation = animation, .action = .{ .free = idx }, .pause_time_nano = 300_000_000 };
            app.operation_manager.push(app.Allocator.allocator(), operation);
        } else @panic("failed to free memory: not allocated");
    }
    allocator.free(indices);
}
