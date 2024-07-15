const std = @import("std");
const SDL = @import("sdl2");
const design = @import("design.zig");
const app = @import("app.zig");
const heap = @import("heap/internal.zig");

pub const Action = union(enum) {
    set_value_heap: struct { idx: usize, value: i64 }, //set a value on the heap.
    allocate: usize,
    free: usize,
    print: []const u8,
    none: void,
};

pub fn perform(action: Action) void {
    switch (action) {
        .set_value_heap => |data| {
            heap.set(data.idx, data.value, app.renderer) catch {};
        },
        .allocate => |idx| {
            heap.allocate(idx) catch {
                @panic("OP: tried to allocate non free memory!!");
            };
        },
        .free => |idx| {
            heap.free(idx) catch {
                @panic("OP: tried to free memory not yours");
            };
        },

        .print => |str| {
            std.debug.print("{s}", .{str});
        },
        .none => {},
    }
}
