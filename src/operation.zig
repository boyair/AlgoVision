const std = @import("std");
const SDL = @import("sdl2");
const design = @import("design.zig");
pub const action = @import("action.zig").action;
const app = @import("app.zig");
const Animation = @import("animation.zig");
const View = @import("view.zig").View;
pub var gpa = std.heap.GeneralPurposeAllocator(.{}){};
pub var OP_alloc = std.heap.ArenaAllocator.init(gpa.allocator());

pub const Operation = union(enum) {
    change_bg: struct { animation: Animation.ZoomAnimation, color: SDL.Color }, //for now used for testing the stack
};

pub var operation_queue: std.DoublyLinkedList(Operation) = undefined;
var current_operation: ?*std.DoublyLinkedList(Operation).Node = undefined;
pub fn init() void {
    operation_queue = std.DoublyLinkedList(Operation){};
    current_operation = operation_queue.first;
}

var animation_copy: ?Animation.ZoomAnimation = null;
pub fn push(operation: Operation) void {
    const node = OP_alloc.allocator().create(std.DoublyLinkedList(Operation).Node) catch {
        @panic("could not allocate memory for operation.");
    };
    node.* = .{
        .data = operation,
    };
    operation_queue.append(node);
    if (operation_queue.len == 1)
        current_operation = operation_queue.first;
}

pub fn performOperations(delta_time: i128, view: *View) void {
    if (current_operation) |operation| {
        switch (operation.data) {
            .change_bg => |data| {
                if (animation_copy == null)
                    animation_copy = data.animation;
                if (!animation_copy.?.done) {
                    view.port = animation_copy.?.update(delta_time);
                } else {
                    design.heap.color_BG = data.color;
                    current_operation = operation.next;
                    animation_copy = null;
                }
            },
        }
    }
}
