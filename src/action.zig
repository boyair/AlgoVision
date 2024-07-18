const std = @import("std");
const SDL = @import("sdl2");
const design = @import("design.zig");
const app = @import("app.zig");
const heap = @import("heap/internal.zig");

pub const actions = enum(u8) {
    set_value_heap,
    search,
    allocate,
    free,
    print,
    none,
};
pub const Action = union(actions) {
    set_value_heap: struct { idx: usize, value: i64 }, //set a value on the heap.
    search: void,
    allocate: usize,
    free: usize,
    print: []const u8,
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
                @panic("OP: tried to free memory not yours");
            };
            return Action{ .allocate = idx };
        },

        .print => |str| {
            std.debug.print("{s}", .{str});
            return Action.none;
        },
        else => {
            return Action.none;
        },
    }
}
