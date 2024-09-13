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
var mem: []usize = undefined;

fn fib(num: []i64) i64 {
    if (num[0] <= 1)
        return num[0];

    var callm1: [1]i64 = .{num[0] - 1};
    var callm2: [1]i64 = .{num[0] - 2};

    const mem1 = app.heap.get(mem[@intCast(callm1[0])]);
    const mem2 = app.heap.get(mem[@intCast(callm2[0])]);

    var result1: i64 = undefined;
    var result2: i64 = undefined;
    if (mem1 == -1) {
        result1 = app.stack.call(fib, &callm1);
        app.heap.set(mem[@intCast(callm1[0])], result1);
    } else {
        result1 = mem1;
    }
    if (mem2 == -1) {
        result2 = app.stack.call(fib, &callm2);
        app.heap.set(mem[@intCast(callm2[0])], result2);
    } else {
        result2 = mem2;
    }
    return result1 + result2;
}

//FIB with CAHCE!!
pub fn main() !void {
    try app.init();
    var num: [1]i64 = .{50};
    mem = app.heap.allocate(gpa.allocator(), 50);

    for (mem) |block| {
        heap.set(block, -1);
    }

    app.log("fib of {d} is {d}", .{ num[0], app.stack.call(fib, &num) });
    app.heap.free(gpa.allocator(), mem);
    //const mem = heap.allocate(gpa.allocator(), 5);
    //heap.set(mem[4], 3);
    try app.start();
}
//TODO
//make ui element take another function as an argument that will handle event (the function should also take its contained type as argument)
//add a checkbox as ui element for toggleable functions (can store the bool in the struct)
//make a pointer (can only be allocated on the heap) with an arrow that points to the address
//make pointer(^) arrows toggleable with a checkbox
//make deinit/close functions for app and heap
//make the init and deinit (^) functions request an allocator (better for testing memory leaks)
//optional: make a wrapper for the init and deinit functions (^) that already has an allocator.
//optional: make allocation, search and free a single action.
//start working on sound
//move logic to another thread to avoid framerate limitation (have a tickrate sepertae from framerate)
//improve ui element for current action. add arrows for fastforward/ undo
