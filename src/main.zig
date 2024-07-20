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
var gpa = std.heap.GeneralPurposeAllocator(.{}){};

pub fn main() !void {
    try app.init();
    const mem = heap.allocate(gpa.allocator(), 4);
    for (mem) |idx| {
        heap.set(idx, 69);
    }
    heap.free(gpa.allocator(), mem);
    try app.start();
}
//TODO
//start making the stack
//make test file for heap
//make deinit/close functions for app and heap
//optional: make allocation, search and free a single action.
