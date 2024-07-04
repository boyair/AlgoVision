const std = @import("std");
const SDL = @import("sdl2");
const Vec2 = @import("Vec2.zig").Vec2;
const View = @import("view.zig").View;
const SDLex = @import("SDLex.zig");
const ZoomAnimation = @import("animation.zig").ZoomAnimation;
const design = @import("design.zig");
const app = @import("app.zig");
const Operation = @import("operation.zig");
const convertSDLRect = SDLex
    .convertSDLRect;

var gpa = std.heap.GeneralPurposeAllocator(.{}){};

pub fn main() !void {
    try app.init();
    const anima = ZoomAnimation.init(app.cam_view.port, .{ .x = -200, .y = -200, .width = 400, .height = 400 }, 4_000_000_000);
    Operation.push(Operation.Operation{ .change_bg = .{ .color = SDL.Color.rgb(244, 0, 9), .animation = anima } });
    try app.start();
}
