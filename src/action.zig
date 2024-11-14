const std = @import("std");
const SDL = @import("sdl2");
const operation = @import("operation.zig");
const animation = @import("animation.zig");
const design = @import("design.zig");
const app = @import("app.zig");
const heap = @import("heap/internal.zig");
const stack = @import("stack/internal.zig");
const Pointer = @import("pointer.zig");

pub const actions = enum(u8) {
    set_value_heap,
    search,
    allocate,
    free,
    make_pointer,
    remove_pointer,
    print,
    call,
    eval_function,
    forget_eval,
    stack_pop,
    stack_unpop,
    none,
};
pub const Action = union(actions) {
    set_value_heap: struct { idx: usize, value: i64 },
    search: void,
    allocate: usize,
    free: usize,
    make_pointer: Pointer.Pointer,
    remove_pointer: struct { source: ?Pointer.Source, destination: ?usize }, //pointer attributes.
    print: []const u8,
    call: stack.MethodData,
    eval_function: i64,
    forget_eval: void,
    stack_pop: void,
    stack_unpop: struct { eval: i64, method: stack.MethodData }, // undoing the pop action requires both pushing it back and evaluate
    none: void,
};

//performs the given action and returns an undo action.
pub fn perform(action: Action) Action {
    switch (action) {
        .set_value_heap => |data| {
            const undo: Action = .{
                .set_value_heap = .{ .idx = data.idx, .value = heap.mem[data.idx].val },
            };
            heap.set(data.idx, data.value) catch {
                @panic("tried to set value at unavailable memory location");
            };
            return undo;
        },
        .allocate => |idx| {
            heap.allocate(idx) catch {
                @panic("OP: tried to allocate non free memory!!");
            };
            return Action{ .free = idx };
        },
        .free => |idx| {
            heap.free(idx) catch {
                @panic("OP: tried to free memory that is not yours");
            };
            return Action{ .allocate = idx };
        },
        .make_pointer => |pointer| {
            switch (pointer.source) {
                .heap => |idx| {
                    heap.setOwnership(idx, .pointer) catch {
                        @panic("OP: tried to set pointer from memory that is not yours");
                    };
                    std.debug.print("set to pointer {d}\n", .{idx});
                },
                .stack => |_| {},
            }
            const node = Pointer.append(pointer, app.Allocator.allocator());
            return Action{ .remove_pointer = .{ .source = node.data.source, .destination = node.data.destination } };
        },
        .remove_pointer => |attributes| {
            const node = Pointer.getByAttribute(attributes.source, attributes.destination) orelse unreachable;
            switch (node.data.source) {
                .heap => |idx| {
                    heap.setOwnership(idx, .user) catch unreachable;
                    std.debug.print("set to pointer {d}\n", .{idx});
                },
                .stack => |_| {},
            }
            return Action{ .make_pointer = Pointer.remove(node) };
        },
        .print => |str| {
            std.debug.print("{s}", .{str});
            return Action.none;
        },
        .call => |method| {
            stack.push(app.Allocator.allocator(), method);
            return Action.stack_pop;
        },
        .eval_function => |eval| {
            stack.evalTop(eval);
            return Action.forget_eval;
        },
        .forget_eval => {
            const eval_save = stack.top_eval;
            stack.forgetEval();
            return if (eval_save) |save| Action{ .eval_function = save } else Action.none;
        },
        .stack_pop => {
            var unpop = Action{ .stack_unpop = .{ .method = stack.stack.last.?.data, .eval = stack.top_eval orelse 0 } };
            stack.pop(app.Allocator.allocator());
            unpop.stack_unpop.method.texture = null;
            return unpop;
        },
        .stack_unpop => |data| {
            stack.push(app.Allocator.allocator(), data.method);
            stack.evalTop(data.eval);
            return Action{ .stack_pop = {} };
        },
        else => {
            return Action.none;
        },
    }
}
