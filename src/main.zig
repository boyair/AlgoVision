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
var gpa = std.heap.GeneralPurposeAllocator(.{}){};

const LinkedList = struct {
    value: i64,
    mem: []usize,
    next: ?*LinkedList,
    const Self = @This();

    fn init(value: i64, allocator: std.mem.Allocator) *LinkedList {
        const list = allocator.create(LinkedList) catch unreachable;
        list.* = .{ .mem = heap.allocate(allocator, 2), .value = value, .next = null };
        heap.set(list.mem[0], value);
        heap.set(list.mem[1], 0);
        return list;
    }

    fn pushBack(self: *Self, value: i64, allocator: std.mem.Allocator) void {
        const new_node = LinkedList.init(value, allocator);
        self.next = new_node;
        heap.setPointer(self.mem[1], new_node.mem[0]);
    }

    fn setNext(self: *Self, next: ?*LinkedList) void {
        if (next) |nxt| {
            heap.setPointer(self.mem[1], nxt.mem[0]);
        } else {
            heap.setPointer(self.mem[1], 0);
        }
        self.next = next;
    }

    fn removeNext(self: *Self, allocator: std.mem.Allocator) void {
        if (self.next) |next| {
            self.setNext(next.next);
            heap.free(allocator, next.mem);
        }
    }
};

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
    //const list = LinkedList.init(5, gpa.allocator());
    _ = app.stack.call(fib, 27);
    //   list.pushBack(69, gpa.allocator());
    //   list.next.?.pushBack(420, gpa.allocator());
    //   list.mem[1] += 2;
    //   list.removeNext(gpa.allocator());
    try app.start();
}
