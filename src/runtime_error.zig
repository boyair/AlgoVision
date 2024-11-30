const std = @import("std");
pub const errors = union(enum) {
    no_available_memrory: usize, //represent buffer size the user wanted to allocate
    memory_not_allocated: usize, //represent address the user wanted to access
    stack_overflow: void,
};

pub fn error_message(err: errors, allocator: std.mem.Allocator) [:0]const u8 {
    return switch (err) {
        .memory_not_allocated => |address| std.fmt.allocPrintZ(allocator, "Error: tried to access not allocated address {d}", .{address}) catch unreachable,
        .no_available_memrory => |size| std.fmt.allocPrintZ(allocator, "Error: cant find block of size {d}", .{size}) catch unreachable,
        .stack_overflow => "Error: stack overflow",
    };
}

//pub var active_error: ?errors = null;
