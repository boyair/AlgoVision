const std = @import("std");
const action = @import("action.zig").action;

const Operation = union(enum) {
    heap_alloc: action(struct { range_start: usize, range_end: usize }), //user called heap.alloc with a size.
};
pub export const OperationQueue = std.DoublyLinkedList(Operation){};
