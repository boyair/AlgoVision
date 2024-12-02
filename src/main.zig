const std = @import("std");
const SDL = @import("SDL");
const Vec2 = @import("Vec2.zig").Vec2;
const View = @import("view.zig").View;
const SDLex = @import("SDLex.zig");
const ZoomAnimation = @import("animation.zig").ZoomAnimation;
const design = @import("design.zig");
const app = @import("app.zig");
const heap = app.heap;
const Operation = @import("operation.zig");
const STD = app.STD;
var gpa = std.heap.GeneralPurposeAllocator(.{}){};

fn factorial(num: i64) i64 {
    if (num <= 1)
        return 1;
    return num * app.stack.call(factorial, num - 1);
}
var mem: []usize = undefined;

fn fib(num: i64) i64 {
    if (num <= 1)
        return num;
    return app.stack.call(fib, (num - 1)) + app.stack.call(fib, (num - 2));
}

pub fn main() !void {
    try app.init();
    var arr = STD.Array.initWithCapacity(gpa.allocator(), 13);
    for (0..12) |idx| {
        arr.insert(@intCast(idx));
    }
    try app.start();
}
