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
//make ui view use the view class with a generated port
//start making the stack
//organize inrternal code for heap
//make test file for heap
//make deinit/close functions for app and heap
//optional: make allocation, search and free a single action.
