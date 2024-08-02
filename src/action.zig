const std = @import("std");
const SDL = @import("sdl2");
const design = @import("design.zig");
const app = @import("app.zig");
const heap = @import("heap/internal.zig");
const stack = @import("stack/internal.zig");

pub const actions = enum(u8) {
    set_value_heap,
    search,
    allocate,
    free,
    print,
    call,
    eval_function,
    forget_eval,
    stack_pop,
    none,
};
pub const Action = union(actions) {
    set_value_heap: struct { idx: usize, value: i64 },
    search: void,
    allocate: usize,
    free: usize,
    print: []const u8,
    call: stack.Method,
    eval_function: i64,
    forget_eval: void,
    stack_pop: void,
    none: void,
};

//performs the given action and returns an undo action.
pub fn perform(action: Action) Action {
    switch (action) {
        .set_value_heap => |data| {
            const undo: Action = .{
                .set_value_heap = .{ .idx = data.idx, .value = heap.mem[data.idx].val },
            };
            heap.set(data.idx, data.value, app.renderer) catch {};
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

        .print => |str| {
            std.debug.print("{s}", .{str});
            return Action.none;
        },
        .call => |method| {
            stack.push(app.Allocator.allocator(), method);
            return Action.stack_pop;
        },
        .stack_pop => {
            var last_method = stack.stack.last.?.data;
            stack.pop(app.Allocator.allocator());
            last_method.texture = null;
            return Action{ .call = last_method };
        },
        .eval_function => |eval| {
            stack.evalTop(app.renderer, eval);
            return Action.forget_eval;
        },
        .forget_eval => {
            const eval_save = stack.top_eval;
            stack.forgetEval(app.renderer);
            return if (eval_save) |save| Action{ .eval_function = save } else Action.none;
        },
        else => {
            return Action.none;
        },
    }
}
