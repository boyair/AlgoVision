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
    pub fn prepend(self: *Self, new_node: *Node) void {
        heap.setPointer(new_node.mem[1], if (self.first) |first| first.mem[0] else 0);
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
        mem: []usize,
        next: ?*Node = null,
        pub fn init(value: i64, allocator: std.mem.Allocator) *Node {
            //creates memory for mode (for real node)
            const node = allocator.create(Node) catch unreachable;
            //creates memory for mode (algovision)
            node.* = .{ .mem = heap.allocate(allocator, 2), .next = null };
            //set value for node and pointer to null (like in its creation on prev line)
            heap.set(node.mem[0], value);
            heap.setPointer(node.mem[1], 0);
            return node;
        }

        pub fn setValue(self: *Node, new_value: i64) void {
            heap.set(self.mem[0], new_value);
        }
        pub fn getValue(self: *Node) i64 {
            return heap.get(self.mem[0]);
        }
        //push a value after a given node
        pub fn insertAfter(self: *Node, new: *Node) void {
            //set pointer from new node to self's next
            heap.setPointer(new.mem[1], if (self.next) |next| next.mem[0] else 0);
            new.next = self.next;
            //set pointer from self to new node
            heap.setPointer(self.mem[1], new.mem[0]);
            //set pointer from self to new node (in real node)
            self.next = new;
        }

        pub fn removeNext(self: *Node, allocator: std.mem.Allocator) void {
            if (self.next) |next| {
                //set pointer to skip next
                self.insertAfter(next.next);
                //free memory of next
                heap.free(allocator, next.mem);
            } else {
                //warn the user for trying to free a a null node.
                app.log("WARNING: tried to free a null node!!\nskipped.\n", .{});
            }
        }
    };
};
