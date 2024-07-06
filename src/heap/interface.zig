const std = @import("std");
const app = @import("../app.zig");
const SDL = @import("sdl2");
const Internals = @import("internal.zig");
const View = @import("../view.zig").View;
const Operation = @import("../operation.zig");
const SDLex = @import("../SDLex.zig");
const design = @import("../design.zig").heap;
const ZoomAnimation = @import("../animation.zig").ZoomAnimation;

pub fn set(idx: usize, value: i64) void {
    var block_view = Internals.blockLocation(idx);
    block_view.x -= design.full_block_size.width * 2;
    block_view.y -= design.full_block_size.height * 2;
    block_view.width += design.full_block_size.width * 4;
    block_view.height += design.full_block_size.height * 4;

    const animation = ZoomAnimation.init(&app.cam_view, null, block_view, 4_000_000_000);

    const operation: Operation.Operation = .{ .animation = animation, .action = .{ .set_value_heap = .{ .idx = idx, .value = value } }, .pause_time_nano = 900_000_000 };

    app.operation_manager.push(operation);
}
