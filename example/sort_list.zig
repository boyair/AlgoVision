const std = @import("std");
const AV = @import("AlgoVision");
var gpa = std.heap.GeneralPurposeAllocator(.{}){}; // allocator required for algovision heap allocations.
const random_values = [_]i64{ 47, 13, 92, 35, 68, 21, 84, 59, 76, 31 }; // list of "random" numbers for demonstrarion purpose.

pub fn main() !void {
    //initiallize AlgoVision
    try AV.init();
    defer AV.start() catch unreachable;

    var list: AV.STD.SinglyLinkedList = .{ .allocator = gpa.allocator() };
    var last_node = AV.STD.SinglyLinkedList.Node.init(random_values[0], gpa.allocator());
    list.prepend(last_node);
    for (1..random_values.len) |idx| {
        last_node.insertAfter(AV.STD.SinglyLinkedList.Node.init(random_values[idx], gpa.allocator()));
        last_node = last_node.next orelse @panic("insertion failure!");
    }
    var start_node = list.first;
    while (start_node) |start| : (start_node = start.next) {
        _ = AV.stack.call(smallest_to_start, start);
    }
}

fn smallest_to_start(starting_node: *AV.STD.SinglyLinkedList.Node) i64 {
    var smallest = starting_node;
    var it = starting_node.next;
    while (it) |cur| : (it = cur.next) {
        if (cur.getValue() < smallest.getValue()) {
            smallest = cur;
        }
    }
    if (smallest.getValue() < starting_node.getValue()) {
        const temp = smallest.getValue();
        smallest.setValue(starting_node.getValue());
        starting_node.setValue(temp);
    }
    return 0;
}
