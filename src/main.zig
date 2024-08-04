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

fn factorial(num: []i64) i64 {
    if (num[0] <= 1)
        return 1;

    var next_call: [1]i64 = .{num[0] - 1};
    const recursion = app.stack.call(factorial, &next_call);
    return recursion * num[0];
}

pub fn main() !void {
    try app.init();
    // var num: [1]i64 = .{7};
    // app.log("fib of {d} is {d}", .{ num[0], app.stack.call(factorial, &num) });
    const mem = heap.allocate(gpa.allocator(), 5);
    heap.set(mem[4], 3);
    try app.start();
}
//TODO
//make a desicion about allocator usage
//add toggle for free cam which will disable zoomanimation
//make deinit/close functions for app and heap
//make the init and deinit (^) functions request an allocator (better for testing memory leaks)
//optional: make a wrapper for the init and deinit functions (^) that already has an allocator.
//optional: make allocation, search and free a single action.
//start working on sound
//move logic to another thread to avoid framerate limitation (have a tickrate sepertae from framerate)
//
