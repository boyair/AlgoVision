const Vec2 = @import("Vec2.zig").Vec2;
const Line = @import("line.zig").Line;
const std = @import("std");
const SDL = @import("sdl2");
const Design = @import("design.zig");
const View = @import("view.zig").View;
const heap = @import("heap/internal.zig");
const stack = @import("stack/internal.zig");
pub var Pointers: std.ArrayList(Pointer) = undefined;

pub const Source = union(enum(u8)) { stack: usize, heap: usize };
inline fn compareSource(a: Source, b: Source) bool {
    if (std.meta.activeTag(a) != std.meta.activeTag(b))
        return false;

    const a_inner_val = switch (a) {
        .heap => |val| val,
        .stack => |val| val,
    };
    const b_inner_val = switch (b) {
        .heap => |val| val,
        .stack => |val| val,
    };

    return a_inner_val == b_inner_val;
}

pub const Pointer = struct {
    source: Source,
    destination: usize, // pointers can only point to the heap so i store only the index
    line: ?Line = null,
    const Self = @This();

    pub fn init(on_heap: bool, src: usize, destination: usize) Self {
        var pointer = Pointer{ .source = if (on_heap) .{ .heap = src } else .{ .stack = src }, .destination = destination };
        _ = pointer.generateLine();
        return pointer;
    }

    pub fn generateLine(self: *Self) Line {
        const source = self.source;
        const end = blk: {
            const rect = heap.blockRect(self.destination);
            break :blk Vec2{ .x = rect.x, .y = rect.y };
        };

        const line: Line =
            switch (source) {
            .stack => |idx| stack: {
                const start = blk: {
                    const y = Design.stack.position.y -
                        idx * Design.stack.method.size.height;
                    const x = Design.stack.position.x + Design.stack.method.size.width;
                    break :blk Vec2{ .x = @floatFromInt(x), .y = @floatFromInt(y) };
                };
                break :stack Line{ .start = start, .end = end };
            },
            .heap => |idx| heap: {
                const start = blk: {
                    const rect = heap.blockRect(idx);
                    break :blk Vec2{ .x = rect.x, .y = rect.y };
                };
                break :heap Line{ .start = start, .end = end };
            },
        };
        self.line = line;
        return line;
    }
};

pub fn init(allocator: std.mem.Allocator) !void {
    Pointers = try std.ArrayList(Pointer).initCapacity(allocator, 10);
}

pub fn deinit() void {
    Pointers.deinit();
}

pub fn append(pointer: Pointer) void {
    var safe_ptr: Pointer = pointer;
    if (safe_ptr.line == null)
        _ = safe_ptr.generateLine();
    Pointers.append(safe_ptr) catch {
        @panic("allocator out of memory.");
    };
    switch (safe_ptr.source) {
        .heap => |idx| {
            heap.set(idx, @intCast(safe_ptr.destination)) catch {
                @panic("tried to set value at unavailable memory location");
            };
        },
        .stack => |idx| {
            heap.set(idx, @intCast(safe_ptr.destination)) catch {
                @panic("tried to set value at unavailable memory location");
            };
        },
    }
}

pub fn remove(index: usize) Pointer {
    return Pointers.orderedRemove(index);
}

pub fn removeByAttribute(source: ?Source, destination: ?usize) void {
    if (source == null and destination == null) return;

    for (Pointers.items, 0..) |*pointer, idx| {
        const comparison = blk: {
            var all_equal = true;
            if (source) |src| {
                all_equal = all_equal and compareSource(pointer.source, src);
            }
            if (destination) |dest| {
                all_equal = all_equal and (pointer.destination == dest);
            }
            break :blk all_equal;
        };
        if (comparison)
            _ = Pointers.orderedRemove(idx);
    }
}

pub fn draw(view: View, renderer: SDL.Renderer) void {
    for (Pointers.items) |pointer| {
        view.drawLine(pointer.line.?, Design.pointer.color, renderer);
    }
}
