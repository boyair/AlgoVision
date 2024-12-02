const std = @import("std");
const app = @import("../app.zig");
const heap = app.heap;
pub const SinglyLinkedList = struct {
    const Self = @This();
    first: ?*Node = null,
    allocator: std.mem.Allocator,
    /// Insert a new node at the head.
    ///
    /// Arguments:
    ///     new_node: Pointer to the new node to insert.
    pub fn prepend(self: *Self, value: i64) void {
        const new_node = Node.init(value, self.allocator);
        if (self.first) |first| {
            heap.setPointer(new_node.mem[1], first.mem[0]);
        }
        new_node.next = self.first;
        self.first = new_node;
    }
    pub fn popFirst(self: *Self) void {
        const first = self.first orelse return;
        heap.free(self.allocator, first.mem);
        self.first = first.next;
        self.allocator.destroy(first);
    }
    pub fn remove(self: *Self, node: *Node) void {
        if (node == self.first) {
            self.popFirst();
            return;
        }
        var current_elm = self.first.?;
        while (current_elm.next != node) {
            const nxt = current_elm.next orelse @panic("could not find the node you are looking for");
            current_elm = nxt;
        }
        if (node.next) |nxt| {
            heap.setPointer(current_elm.mem[1], nxt.mem[0]);
        }
        current_elm.next = node.next;
        heap.free(self.allocator, node.mem);
        self.allocator.destroy(node);
    }

    pub const Node = struct {
        value: i64,
        mem: []usize,
        next: ?*Node = null,

        fn init(value: i64, allocator: std.mem.Allocator) *Node {
            const list = allocator.create(Node) catch unreachable;
            list.* = .{ .mem = heap.allocate(allocator, 2), .value = value, .next = null };
            heap.set(list.mem[0], value);
            heap.set(list.mem[1], 0);
            return list;
        }

        //push a value to the end of the list

        fn insertAfter(self: *Node, next: ?*Node) void {
            if (next) |nxt| {
                heap.setPointer(self.mem[1], nxt.mem[0]);
            } else {
                heap.setPointer(self.mem[1], 0);
            }
            self.next = next;
        }

        fn removeNext(self: *Node, allocator: std.mem.Allocator) void {
            if (self.next) |next| {
                self.insertAfter(next.next);
                heap.free(allocator, next.mem);
            }
        }
    };
};
