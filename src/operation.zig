const std = @import("std");
const SDL = @import("sdl2");
const design = @import("design.zig");
pub const Action = @import("action.zig");
const app = @import("app.zig");
const Animation = @import("animation.zig");
const View = @import("view.zig").View;
pub var gpa = std.heap.GeneralPurposeAllocator(.{}){};
pub var OP_alloc = std.heap.ArenaAllocator.init(gpa.allocator());

const OperationState = enum(u8) {
    animate = 1,
    act = 2,
    pause = 3,
    done = 4,
};

pub const Operation = struct {
    animation: Animation.ZoomAnimation,
    pause_time_nano: i128,
    action: Action.Action,
};

pub const Manager = struct {
    operation_queue: std.DoublyLinkedList(Operation),
    current_operation: ?*std.DoublyLinkedList(Operation).Node,
    animation_state: Animation.ZoomAnimation, // a copy of current animation to not affect the animation directly in the operation.
    time_paused: i128,
    state: OperationState,

    pub fn init() Manager {
        return .{
            .operation_queue = std.DoublyLinkedList(Operation){},
            .current_operation = undefined,
            .animation_state = undefined,
            .time_paused = 0,
            .state = OperationState.animate,
        };
    }

    pub fn push(self: *Manager, operation: Operation) void {
        const node = OP_alloc.allocator().create(std.DoublyLinkedList(Operation).Node) catch {
            @panic("could not allocate memory for operation.");
        };

        node.* = .{
            .data = operation,
        };

        self.operation_queue.append(node);
        //init currents on first push
        if (self.operation_queue.len == 1) {
            self.current_operation = self.operation_queue.first;
            self.animation_state = self.current_operation.?.data.animation;
        }
    }

    pub fn update(self: *Manager, delta_time: i128) void {
        if (self.current_operation) |current_operation| {
            switch (self.state) {
                .animate => {
                    self.animation_state.update(delta_time);
                    if (self.animation_state.done)
                        self.state = OperationState.act;
                },
                .act => {
                    Action.perform(current_operation.data.action);
                    self.state = OperationState.pause;
                },
                .pause => {
                    self.time_paused += delta_time;
                    if (self.time_paused >= current_operation.data.pause_time_nano)
                        self.state = OperationState.done;
                },
                .done => {
                    self.current_operation = current_operation.next;
                    const current_view = current_operation.data.animation.end_state;
                    self.animation_state = if (current_operation.next) |nxt| nxt.data.animation else Animation.ZoomAnimation.init(self.animation_state.view, current_view, current_view, 0);
                    self.animation_state.start_state = current_view;
                    self.time_paused = 0;
                    self.state = OperationState.animate;
                },
            }
        }
    }
};
