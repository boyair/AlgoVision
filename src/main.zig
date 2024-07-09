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
    //heap.set(9, 645319);
    //heap.set(62, 69);
    //heap.set(99, 69);
    try app.start();
}
