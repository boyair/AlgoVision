const std = @import("std");
const SDL = @import("sdl2");
const Vec2 = @import("Vec2.zig").Vec2;
const View = @import("view.zig").View;
const SDLex = @import("SDLex.zig");
const ZoomAnimation = @import("animation.zig").ZoomAnimation;
const design = @import("design.zig");
const app = @import("app.zig");
const convertSDLRect = SDLex
    .convertSDLRect;

var gpa = std.heap.GeneralPurposeAllocator(.{}){};

pub fn main() !void {
    try app.init();
    _ = try app.heap.alloc(4);
    try app.start();
}
