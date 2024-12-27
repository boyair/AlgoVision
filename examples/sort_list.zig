const std = @import("std");
const AV = @import("AlgoVision");
var gpa = std.heap.GeneralPurposeAllocator(.{}){}; // allocator required for algovision heap allocations.
const random_values = [_]i64{ 47, 13, 92, 35, 68, 21, 84, 59, 76, 31 }; // list of "random" numbers for demonstrarion purpose.

pub fn main() !void {
    //initiallize AlgoVision
    try AV.init();
    defer AV.start() catch unreachable;

    //initiallize list and add first node to it
    var list: AV.STD.SinglyLinkedList = .{ .allocator = gpa.allocator() };
    var last_node = AV.STD.SinglyLinkedList.Node.init(random_values[0], gpa.allocator());
    list.prepend(last_node);

    //get entire list of random values in the same order to the list
    for (1..random_values.len) |idx| {
        last_node.insertAfter(AV.STD.SinglyLinkedList.Node.init(random_values[idx], gpa.allocator()));
        last_node = last_node.next orelse @panic("insertion failure!");
    }

    var start_node = list.first;
    //move smallest element to start and move start to the next value iteratively
    while (start_node) |start| : (start_node = start.next) {
        _ = AV.stack.call(smallest_to_start, start);
    }
}

///this function takes a starting node and swaps its value with
///with the smallest node in the rest of the list
///
///return value is always zero and is there just to conform to
///AlgoVision function call rulings
fn smallest_to_start(starting_node: *AV.STD.SinglyLinkedList.Node) i64 {
    var smallest = starting_node; // saves the node contatining the smallest element

    // capture the node contatining the smallest element:
    var it = starting_node.next;
    while (it) |cur| : (it = cur.next) {
        if (cur.getValue() < smallest.getValue()) {
            smallest = cur;
        }
    }

    //swap smallest node value with staring node value:
    if (smallest.getValue() < starting_node.getValue()) {
        const temp = smallest.getValue();
        smallest.setValue(starting_node.getValue());
        starting_node.setValue(temp);
    }
    return 0;
}
