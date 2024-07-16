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
    const mem = heap.allocate(40);
    var sum: i64 = 0;
    for (mem) |idx| {
        sum += heap.get(idx);
        heap.set(idx, @intCast(idx));
    }
    app.log("number:  {d}\n", .{heap.get(mem[0])});
    heap.set(mem[0], sum);
    app.heap.free(mem);
    const mem27 = heap.allocate(27);
    for (mem27) |idx| {
        heap.set(idx, @intCast(idx));
    }
    app.log("DONE!\n", .{});
    app.log("{d},{d},{d},{d}\n", app.cam_view.port);
    try app.start();
}
//TODO move to using ttf module from SDL.zig
