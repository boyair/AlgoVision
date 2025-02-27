const std = @import("std");
const SDL = @import("SDL");
const rt_err = @import("runtime_error.zig");
const SDLex = @import("SDLex.zig");
const design = @import("design.zig");
pub const Action = @import("action.zig");
const app = @import("app.zig");
const Animation = @import("animation.zig");
const View = @import("view.zig").View;
pub var gpa = std.heap.GeneralPurposeAllocator(.{}){};

const OperationState = enum(u8) {
    animate,
    act,
    pause,
    done,
};

pub const Operation = struct {
    animation: Animation.ZoomAnimation,
    pause_time_nano: i128,
    action: Action.Action,
};

pub const Undo = struct {
    view: SDL.RectangleF,
    action: Action,
};

pub const Manager = struct {
    operation_queue: std.DoublyLinkedList(Operation),
    undo_queue: std.DoublyLinkedList(Action.Action),
    current_operation: ?*std.DoublyLinkedList(Operation).Node,
    animation_state: Animation.ZoomAnimation, // a copy of current animation to not affect the animation directly.
    time_paused: i128,
    state: OperationState,
    blocked_by_error: bool = false,
    const Self = @This();

    pub fn init() Self {
        return .{
            .operation_queue = std.DoublyLinkedList(Operation){},
            .undo_queue = std.DoublyLinkedList(Action.Action){},
            .current_operation = undefined,
            .animation_state = undefined,
            .time_paused = 0,
            .state = OperationState.animate,
        };
    }
    pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
        while (self.operation_queue.pop()) |node| {
            allocator.destroy(node);
        }
        while (self.undo_queue.pop()) |node| {
            allocator.destroy(node);
        }
    }

    pub fn push(self: *Self, allocator: std.mem.Allocator, operation: Operation) void {
        if (self.blocked_by_error) // first error is always the last operation.
            return;
        const node = allocator.create(std.DoublyLinkedList(Operation).Node) catch {
            @panic("could not allocate memory for operation.");
        };

        node.* = .{
            .data = operation,
        };

        self.operation_queue.append(node);
        //init states on first push
        if (self.operation_queue.len == 1) {
            self.current_operation = self.operation_queue.first;
            self.animation_state = self.current_operation.?.data.animation;
        }
        if (node.data.action == .runtime_error) {
            self.blocked_by_error = true;
        }
    }
    pub fn insertNext(self: *Self, allocator: std.mem.Allocator, operation: Operation) void {
        const node = allocator.create(std.DoublyLinkedList(Operation).Node) catch {
            @panic("could not allocate memory for operation.");
        };

        node.* = .{
            .data = operation,
        };
        self.operation_queue.insertAfter(self.current_operation.?, node);
    }

    pub fn update(self: *Self, delta_time: i128, animate: bool) void {
        if (self.current_operation) |current_operation| {
            switch (self.state) {
                .animate => {
                    if (!self.animation_state.isDone()) {
                        if (animate) {
                            self.animation_state.update(delta_time);
                        } else {
                            self.animation_state.passed_duration += delta_time;
                        }
                        return;
                    }
                },
                .act => {
                    var maybe_sound = Action.getSound(std.meta.activeTag(current_operation.data.action));
                    if (maybe_sound) |*sound| {
                        sound.play(90, 0) catch unreachable;
                    }

                    //create undo node
                    const undo_node = app.Allocator.allocator().create(std.DoublyLinkedList(Action.Action).Node) catch unreachable;
                    undo_node.* = .{
                        .data = Action.perform(current_operation.data.action), //action performed here.
                    };
                    self.undo_queue.append(undo_node);
                },
                .pause => {
                    self.time_paused += delta_time;
                    if (!(self.time_paused >= current_operation.data.pause_time_nano))
                        return;
                },
                .done => {
                    self.current_operation = current_operation.next orelse current_operation;
                    if (current_operation == self.operation_queue.last) {
                        return;
                    }
                    const current_view = app.cam_view.cam;
                    self.animation_state = if (current_operation.next) |nxt| nxt.data.animation else Animation.ZoomAnimation.init(self.animation_state.view, current_view, current_view, 0);
                    self.animation_state.start_state = current_view;
                    self.time_paused = 0;
                },
            }
            //iterate states
            self.state = @enumFromInt((@intFromEnum(self.state) + 1) % (@intFromEnum(OperationState.done) + 1));
        }
    }

    pub fn undoLast(self: *Self) void {
        const was_current_performed = @intFromEnum(self.state) > @intFromEnum(OperationState.act);
        //find last operation (if not found return)
        const last_performed = blk: {
            if (self.current_operation) |op| {
                if (was_current_performed) {
                    break :blk self.current_operation;
                }
                if (op.prev) |prev| {
                    break :blk prev;
                }
            }
            return;
        };
        //call last undo and pop it
        _ = Action.perform(self.undo_queue.pop().?.data);
        //move current_operation pointer one operation back
        self.current_operation = last_performed;
        self.resetState();
        //recall self recursively if action has no duration.
        //used to prevent undoing being impossible for thing like printing which dosent take time.
        if (self.current_operation.?.data.animation.total_duration == 0 and self.current_operation.?.data.pause_time_nano == 0)
            self.undoLast();
    }
    fn resetState(self: *Self) void {
        if (self.current_operation == null)
            return;
        const current_view =
            if (self.current_operation.?.prev) |prev| prev.data.animation.end_state else self.current_operation.?.data.animation.end_state;
        self.animation_state = self.current_operation.?.data.animation;
        self.state = OperationState.animate;
        self.animation_state.start_state = current_view;
    }
    pub fn fastForward(self: *Self) void {
        if (self.current_operation == null)
            return;
        const current_performed = @intFromEnum(self.state) > @intFromEnum(OperationState.act);
        // perform action if not performed.
        if (!current_performed) {
            const undo_node = app.Allocator.allocator().create(std.DoublyLinkedList(Action.Action).Node) catch {
                @panic("could not allocate memory for operation.");
            };
            undo_node.data = Action.perform(self.current_operation.?.data.action); //action performed here.
            self.undo_queue.append(undo_node);
        }

        self.state = .done;
        self.update(0, false);
    }

    pub fn pushError(self: *Self, err: rt_err.errors) void {
        const non_animation = Animation.nonAnimation();
        const operation: Operation = .{ .animation = non_animation, .action = .{ .runtime_error = err }, .pause_time_nano = 0 };
        self.push(app.Allocator.allocator(), operation);
        std.debug.print("pushed error!!\n", .{});
    }
};
