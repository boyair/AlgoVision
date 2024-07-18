const std = @import("std");
const SDL = @import("sdl2");
const Vec2 = @import("Vec2.zig").Vec2;
const View = @import("view.zig").View;
const SDLex = @import("SDLex.zig");
const ZoomAnimation = @import("animation.zig").ZoomAnimation;
const design = @import("design.zig");
const app = @import("app.zig");
const heap = app.heap;
const Operation = @import("operation.zig");

pub fn main() !void {
    try app.init();
    const mem = heap.allocate(4);
    for (mem) |idx| {
        heap.set(idx, 69);
    }
    try app.start();
}
//TODO
//complete undo system
//change window to be fullscreen (make it work on all 16:9 resolutions)
//make a seperate renderer for UI on the left(leave a squre region for the regular view)
//start making the stack
//organize inrternal code for heap
//make test file for heap
