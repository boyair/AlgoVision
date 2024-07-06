const std = @import("std");
const SDL = @import("sdl2");
const design = @import("design.zig");
const app = @import("app.zig");
const heap = @import("heap/internal.zig");

pub const Action = union(enum) {
    change_bg: struct { color: SDL.Color }, //for now used for testing.
    set_value_heap: struct { idx: usize, value: i64 }, //set a value on the heap.
};

pub fn perform(action: Action) void {
    switch (action) {
        .change_bg => |data| {
            design.heap.color_BG = data.color;
        },
        .set_value_heap => |data| {
            heap.set(data.idx, data.value, app.renderer) catch {};
        },
    }
}

test "perform" {
    app.init();
    const set_mem_420 = Action{ .set_value_heap = .{ .idx = 2, .value = 420 } };
    perform(set_mem_420);
    std.testing.expectEqual(heap.mem[2], 420);
    const set_mem_59 = Action{ .set_value_heap = .{ .idx = 4, .value = 59 } };
    perform(set_mem_59);
    std.testing.expectEqual(heap.mem[4], 59);
}
