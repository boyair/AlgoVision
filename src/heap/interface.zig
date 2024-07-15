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
    if (end < start)
        return error.invalidRange;
    var range_view: SDL.RectangleF = Internals.blockRect(start);
    var avarage_loc: Vec2 = .{ .x = 0, .y = 0 };
    for (start..end) |idx| {
        const block_rect = Internals.blockRect(idx);
        range_view.x = @min(range_view.x, block_rect.x);
        range_view.y = @min(range_view.y, block_rect.y);
        range_view.width = @max(range_view.width, block_rect.x + block_rect.width - range_view.x);
        range_view.height = @max(range_view.height, block_rect.x + block_rect.width - range_view.x);
        avarage_loc.x += block_rect.x;
        avarage_loc.y += block_rect.y;
    }
    avarage_loc.x /= @floatFromInt(end - start);
    avarage_loc.y /= @floatFromInt(end - start);
    avarage_loc.x += design.block.full_size.width / 2;
    avarage_loc.y += design.block.full_size.height / 2;

    //keep 1:1 ratio
    range_view.width = @max(range_view.width, range_view.height);
    range_view.height = @max(range_view.width, range_view.height);
    range_view.x = avarage_loc.x - range_view.width / 2;
    range_view.y = avarage_loc.y - range_view.width / 2;

    range_view.x -= design.block.full_size.width * 4;
    range_view.y -= design.block.full_size.height * 4;
    range_view.width += design.block.full_size.width * 8;
    range_view.height += design.block.full_size.height * 8;
    return range_view;
}

pub fn set(idx: usize, value: i64) void {
    const block_view = blockView(idx);
    const animation = ZoomAnimation.init(&app.cam_view, null, block_view, 200_000_000);

    const operation: Operation.Operation = .{ .animation = animation, .action = .{ .set_value_heap = .{ .idx = idx, .value = value } }, .pause_time_nano = 200_000_000 };
    Internals.mem_runtime[idx].val = value;

    app.operation_manager.push(operation);
}

pub fn get(idx: usize) i64 {
    //const block_view = blockView(idx);
    //const animation = ZoomAnimation.init(&app.cam_view, null, block_view, 1_000_000_000);

    // const operation: Operation.Operation = .{ .animation = animation, .action = .{ .none = {} }, .pause_time_nano = 900_000_000 };

    // app.operation_manager.push(operation);
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

pub fn allocate(size: usize) []usize {
    const range = Internals.findFreeRange(size) catch {
        @panic("could not find large enough buffer");
    };

    for (0..range.start) |idx| {
        const block_view = blockView(idx);
        const animation = ZoomAnimation.init(&app.cam_view, null, block_view, 200_000_000);
        const operation: Operation.Operation = .{ .animation = animation, .action = .{ .none = {} }, .pause_time_nano = 200_000_000 };
        app.operation_manager.push(operation);
    }
    var indexes = std.ArrayList(usize).init(Internals.gpa.allocator());
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

pub fn free(indices: []usize) void {
    for (indices) |idx| {
        if (Internals.mem_runtime[idx].owner == .user) {
            Internals.mem_runtime[idx].owner = .free;
            const animation = ZoomAnimation.init(&app.cam_view, null, blockView(idx), 200_000_000);
            const operation: Operation.Operation = .{ .animation = animation, .action = .{ .free = idx }, .pause_time_nano = 200_000_000 };
            app.operation_manager.push(operation);
        } else @panic("failed to free memory: not allocated");
    }
    Internals.gpa.allocator().free(indices);
}
