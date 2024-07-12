const std = @import("std");
const SDL = @import("sdl2");
const Vec2 = @import("Vec2.zig").Vec2;
const View = @import("view.zig").View;
const SDLex = @import("SDLex.zig");
const ZoomAnimation = @import("animation.zig").ZoomAnimation;
const design = @import("design.zig");
const app = @import("app.zig");
const heap = @import("heap/interface.zig");
const Operation = @import("operation.zig");

pub fn main() !void {
    try app.init();
    const mem = heap.allocate(5);
    for (mem) |idx| {
        heap.set(idx, @intCast(idx));
    }
    const mem27 = heap.allocate(27);
    for (mem27) |idx| {
        heap.set(idx, @intCast(idx));
    }
    try app.start();
}
