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
const SLL = app.STD.SinglyLinkedList;
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
    var list = SLL{ .allocator = gpa.allocator() };
    var fifth: *SLL.Node = undefined;
    for (0..40) |idx| {
        list.prepend(@intCast(idx));
        if (idx == 0)
            fifth = list.first.?;
    }
    list.remove(fifth);
    //const list = LinkedList.init(5, gpa.allocator());
    //  _ = app.stack.call(fib, 27);
    //   list.pushBack(69, gpa.allocator());
    //   list.next.?.pushBack(420, gpa.allocator());
    //   list.mem[1] += 2;
    //   list.removeNext(gpa.allocator());
    try app.start();
}
