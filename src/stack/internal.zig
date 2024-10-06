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
    design.frame.texture = try SDLex.loadResource(app.exe_path, "/textures/ram.png", app.renderer);
}
//NOTE:
//to solve the texture is null when drawing the mutex should lock before adding the method in the sending thread (X)!!
//and should be unlocked after drawing in the main thread (V)
//so that there is no possible timing where the method is added and draw to the screen
//before its texture was created.
var signal_count: u64 = 0;
var TextureUpdateMut = struct {
    mutex: std.Thread.Mutex,
    condition: std.Thread.Condition,
    needs_update: bool,
}{ .mutex = .{}, .condition = .{}, .needs_update = false };
//function to handle signaling the main thread to update the textures
fn sendTextureUpdateSignal() void {
    TextureUpdateMut.needs_update = true;
    signal_count += 1;
    while (TextureUpdateMut.needs_update) {
        std.debug.print("sent signal {d}. waiting . . .\n", .{signal_count});
        TextureUpdateMut.condition.wait(&TextureUpdateMut.mutex);
    }
    std.debug.print("signal {d} was waited\n", .{signal_count});
}

//-----------------------------------------------------------------------

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
    TextureUpdateMut.mutex.lock();
    defer TextureUpdateMut.mutex.unlock();
    const node = allocator.create(std.DoublyLinkedList(Method).Node) catch unreachable;
    node.data = method;
    stack.append(node);
    sendTextureUpdateSignal();
}
pub fn pop(allocator: std.mem.Allocator) void {
    TextureUpdateMut.mutex.lock();
    defer TextureUpdateMut.mutex.unlock();
    if (stack.pop()) |last| {
        if (last.data.texture) |texture| {
            texture.destroy();
        }
        allocator.destroy(last);
    }
    top_eval = null;
}

pub fn draw(renderer: SDL.Renderer, view: View) void {
    TextureUpdateMut.mutex.lock();
    defer TextureUpdateMut.mutex.unlock();
    if (TextureUpdateMut.needs_update) {
        std.debug.print("recived signal {d}. processing . . .\n", .{signal_count});
        if (stack.last) |top_method| {
            top_method.data.makeTexture(app.renderer) catch unreachable;
            TextureUpdateMut.needs_update = false;
            TextureUpdateMut.condition.signal();
        }
    }
    view.draw(SDLex.convertSDLRect(design.frame.rect), design.frame.texture, app.renderer);
    var it = stack.first;
    var currentY = design.position.y;
    while (it) |node| : ({
        it = it.?.next;
        currentY -= design.method.size.height;
    }) {
        var converted_rect: SDL.RectangleF = view.convert(SDLex.convertSDLRect(SDL.Rectangle{ .x = design.position.x, .y = currentY, .width = design.method.size.width, .height = design.method.size.height })) catch continue;
        converted_rect.width += 1;
        converted_rect.height += 1;
        renderer.copy(node.data.texture.?, SDLex.convertSDLRect(converted_rect), null) catch {
            @panic("failed to draw method!");
        };
    }
}

pub fn evalTop(renderer: SDL.Renderer, value: i64) void {
    TextureUpdateMut.mutex.lock();
    defer TextureUpdateMut.mutex.unlock();
    _ = renderer;
    if (stack.last) |top| {
        _ = top;
        top_eval = value;
        sendTextureUpdateSignal();
    }
}

pub fn forgetEval(renderer: SDL.Renderer) void {
    TextureUpdateMut.mutex.lock();
    defer TextureUpdateMut.mutex.unlock();
    _ = renderer;
    if (stack.last) |top| {
        _ = top;
        top_eval = null;
        sendTextureUpdateSignal();
    }
}
