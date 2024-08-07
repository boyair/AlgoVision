const std = @import("std");
const SDL = @import("sdl2");
const SDLex = @import("../SDLex.zig");
const design = @import("../design.zig").stack;
const app = @import("../app.zig");
const View = @import("../view.zig").View;

pub var stack: std.DoublyLinkedList(Method) = undefined;
pub var top_eval: ?i64 = null;

pub fn init() !void {
    stack = std.DoublyLinkedList(Method){};
    design.font = try SDLex.loadResource(app.exe_path, "/ioveska.ttf", app.renderer);
    design.method.bg = try SDLex.loadResource(app.exe_path, "/textures/method.png", app.renderer);
}

pub const Method = struct {
    const Self = @This();
    function: *const fn ([]i64) i64,
    args: std.ArrayList(i64),
    texture: ?SDL.Texture = null,

    pub fn fmt(self: Self, allocator: std.mem.Allocator) []u8 {
        return std.fmt.allocPrint(allocator, "fn ({any})", .{self.args.items.ptr[0..self.args.items.len]}) catch unreachable;
    }
    pub fn fmtZ(self: Self, allocator: std.mem.Allocator) [:0]u8 {
        return std.fmt.allocPrintZ(allocator, "fn ({any})", .{self.args.items.ptr[0..self.args.items.len]}) catch unreachable;
    }
    fn makeTexture(self: *Method, renderer: SDL.Renderer) !void {
        if (self.texture) |prev_tex| {
            prev_tex.destroy();
        }

        const text =
            if (top_eval) |eval| std.fmt.allocPrintZ(app.Allocator.allocator(), "{d}", .{eval}) catch unreachable else self.fmtZ(app.Allocator.allocator());
        defer app.Allocator.allocator().free(text);
        const design_texture_info = design.method.bg.query() catch unreachable;
        const texture_rect: SDL.Rectangle = .{ .x = 0, .y = 0, .width = @intCast(design_texture_info.width), .height = @intCast(design_texture_info.height) };
        const texture = try SDL.createTexture(renderer, .rgba8888, .target, design_texture_info.width, design_texture_info.height);
        //copy design texture
        try renderer.setTarget(texture);
        try renderer.copy(design.method.bg, null, null);
        //create text texture and place it on copy
        const text_texture = SDLex.textureFromText(text, design.font, design.method.fg, renderer);
        const text_size: SDL.Size = .{ .width = @intCast(40 * text.len), .height = 250 };
        const text_rect = SDLex.alignedRect(texture_rect, .{ .x = 0.5, .y = 0.5 }, text_size);
        try renderer.copy(text_texture, text_rect, null);
        self.texture = texture;
        try renderer.setTarget(null);
    }
};

pub fn push(allocator: std.mem.Allocator, method: Method) void {
    const node = allocator.create(std.DoublyLinkedList(Method).Node) catch unreachable;
    node.data = method;
    stack.append(node);

    stack.last.?.data.makeTexture(app.renderer) catch unreachable;
}
pub fn pop(allocator: std.mem.Allocator) void {
    if (stack.pop()) |last| {
        if (last.data.texture) |texture| {
            texture.destroy();
        }
        allocator.destroy(last);
    }
    top_eval = null;
}

pub fn draw(renderer: SDL.Renderer, view: View) void {
    var it = stack.first;
    var currentY = design.position.y;
    while (it) |node| : (it = it.?.next) {
        view.draw(SDLex.convertSDLRect(SDL.Rectangle{ .x = design.position.x, .y = currentY, .width = 1000, .height = 500 }), node.data.texture.?, renderer);
        currentY -= 500;
    }
}

pub fn evalTop(renderer: SDL.Renderer, value: i64) void {
    if (stack.last) |top| {
        top_eval = value;
        top.data.makeTexture(renderer) catch unreachable;
    }
}

pub fn forgetEval(renderer: SDL.Renderer) void {
    if (stack.last) |top| {
        top_eval = null;
        top.data.makeTexture(renderer) catch unreachable;
        top_eval = null;
    }
}
