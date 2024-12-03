const Vec2 = @import("Vec2.zig").Vec2;
const Line = @import("line.zig").Line;
const std = @import("std");
const SDL = @import("SDL");
const SDLex = @import("SDLex.zig");
const Design = @import("design.zig");
const View = @import("view.zig").View;
const heap = @import("heap/internal.zig");
const stack = @import("stack/internal.zig");
pub var Pointers: std.DoublyLinkedList(Pointer) = undefined;

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
        const end_rect = heap.blockRect(self.destination);

        const start: Vec2 =
            switch (source) {
            .stack => |idx| stack: {
                const y = Design.stack.position.y -
                    @as(c_int, @intCast(idx * Design.stack.method.size.height));
                const x = Design.stack.position.x + Design.stack.method.size.width;
                break :stack Vec2{ .x = @floatFromInt(x), .y = @floatFromInt(y) };
            },
            .heap => |idx| heap: {
                const rect = heap.blockRect(idx);
                const nearest_corner = Vec2{
                    .x = if (rect.x > end_rect.x) rect.x else rect.x + rect.width,
                    .y = if (rect.y > end_rect.y) rect.y else rect.y + rect.height,
                };
                break :heap nearest_corner;
            },
        };
        const end = Vec2{
            .x = if (end_rect.x >= start.x) end_rect.x else end_rect.x + end_rect.width,
            .y = if (end_rect.y >= start.y) end_rect.y else end_rect.y + end_rect.height,
        };
        self.line = .{ .start = start, .end = end };
        return self.line.?;
    }
};

//removes all pointers sourced in unallocated memory.
pub fn update() void {
    var it = Pointers.first;
    while (it) |node| : (it = node.next) {
        const source = node.data.source;
        switch (source) {
            .heap => |idx| {
                if (heap.mem[idx].owner != .pointer) {
                    std.debug.print("removed node\n", .{});
                    Pointers.remove(node);
                }
            },
            .stack => |_| {},
        }
    }
}
pub fn init(exe_path: []const u8, renderer: SDL.Renderer) !void {
    Design.pointer.arrow = try SDLex.loadResource(exe_path, "/textures/pointer.png", renderer);
}

pub fn deinit() void {
    Pointers.deinit();
}

pub fn append(pointer: Pointer, allocator: std.mem.Allocator) *std.DoublyLinkedList(Pointer).Node {
    var safe_ptr: *std.DoublyLinkedList(Pointer).Node = allocator.create(std.DoublyLinkedList(Pointer).Node) catch unreachable;
    safe_ptr.data = pointer;
    var data = safe_ptr.data;
    if (data.line == null)
        _ = data.generateLine();
    Pointers.append(safe_ptr);
    switch (data.source) {
        .heap => |idx| {
            heap.set(idx, @intCast(data.destination)) catch {
                @panic("tried to set value at unavailable memory location");
            };
        },
        .stack => |idx| {
            heap.set(idx, @intCast(data.destination)) catch {
                @panic("tried to set value at unavailable memory location");
            };
        },
    }
    return safe_ptr;
}

pub fn remove(node: *std.DoublyLinkedList(Pointer).Node) Pointer {
    const pointer = node.data;
    if (Pointers.len > 0)
        Pointers.remove(node);
    return pointer;
}

pub fn getByAttribute(source: ?Source, destination: ?usize) ?*std.DoublyLinkedList(Pointer).Node {
    if (source == null and destination == null) return null;
    var it = Pointers.first;
    while (it) |node| : (it = node.next) {
        const comparison = blk: {
            var all_equal = true;
            if (source) |src| {
                all_equal = all_equal and compareSource(node.data.source, src);
            }
            if (destination) |dest| {
                all_equal = all_equal and (node.data.destination == dest);
            }
            break :blk all_equal;
        };
        if (comparison) {
            return node;
        }
    }
    return null;
}

pub fn draw(view: View, renderer: SDL.Renderer) void {
    var it = Pointers.first;
    while (it) |node| : (it = node.next) {
        //drawLine(view, renderer);
        drawPointer(&node.data, view, renderer);
    }
}

pub fn drawPointer(pointer: *Pointer, view: View, renderer: SDL.Renderer) void {
    const line: Line = if (pointer.line) |ln| ln else pointer.generateLine();
    const diff = Vec2{ .x = line.diffx(), .y = line.diffy() };
    const distance = line.Length();
    if (distance < 120) {
        view.drawLine(line, SDL.Color.red, renderer);
        return;
    }
    const arrow_length = 100;
    const reduced_distance = distance - arrow_length;
    const intersectionX = line.start.x + diff.x * reduced_distance / distance;
    const intersectionY = line.start.y + diff.y * reduced_distance / distance;
    view.drawLine(.{ .start = line.start, .end = .{ .x = intersectionX, .y = intersectionY } }, SDL.Color.red, renderer);
    view.drawEx(.{ .x = intersectionX, .y = intersectionY - 25, .width = 100, .height = 50 }, Design.pointer.arrow, renderer, diff.getAngle() * 180 / std.math.pi, .{ .x = 0, .y = 0.5 }, .none);
}
