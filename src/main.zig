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

fn factorial(num: i64) i64 {
    if (num <= 1)
        return 1;
    return num * app.stack.call(factorial, num - 1);
}
var mem: []usize = undefined;

fn fib(num: i64) i64 {
    if (num <= 1)
        return num;
    const heap_val = heap.get(mem[@intCast(num - 1)]);
    if (heap_val != -1)
        return heap_val;
    const result = app.stack.call(fib, (num - 1)) + app.stack.call(fib, (num - 2));
    heap.set(mem[@intCast(num - 1)], result);
    return result;
}

//FIB with CAHCE!!
pub fn main() !void {
    try app.init();
    app.log("{d} factorial is {d}\n", .{ 7, app.stack.call(factorial, 7) });
    try app.start();
}

//TODO:
//make a pointer (can only be allocated on the heap) with an arrow that points to the address
//make pointer(^) arrows toggleable with a checkbox
//start working on sound
//improve api to make it look more like zig code and not like a new language

//the following code should work once pointers are implemented:
//mem[0] = heap.new(2) //pointer to block of size 2
//const block1: heap.pointer = heap.dereferance(mem[0])
