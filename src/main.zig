const std = @import("std");
const SDL = @import("SDL");
const app = @import("AlgoVision");
const heap = app.heap;
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
    defer app.start() catch unreachable;
    app.log("5 factorial is {d}", .{app.stack.call(fib, 30)});
}
