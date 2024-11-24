const std = @import("std");
const SDL = @import("SDL");
const SDLex = @import("../SDLex.zig");
const design = @import("../design.zig").stack;
const app = @import("../app.zig");
const View = @import("../view.zig").View;
const heap = @import("../heap/internal.zig");

pub var stack: std.DoublyLinkedList(MethodData) = undefined;
pub var top_eval: ?i64 = null;
var textureGarbage: std.ArrayList(SDL.Texture) = undefined;

pub fn init(exe_path: []const u8, comptime font_path: []const u8) !void {
    stack = std.DoublyLinkedList(MethodData){};
    design.font = try SDLex.loadResource(exe_path, font_path, app.renderer);
    design.method.bg = try SDLex.loadResource(exe_path, "/textures/method.png", app.renderer);
    textureGarbage = try std.ArrayList(SDL.Texture).initCapacity(app.Allocator.allocator(), 3);

    design.frame.texture = try SDLex.loadResource(app.exe_path, "/textures/ram.png", app.renderer);
}
pub fn deinit(allocator: std.mem.Allocator) void {
    for (stack.pop()) |node| {
        node.destroyTexure();
        allocator.destroy(node);
    }
    textureGarbage.deinit();
    design.font.close();
    design.method.bg.destroy();
    design.frame.texture.destroy();
}

var TextureUpdateMut = struct {
    mutex: std.Thread.Mutex,
    condition: std.Thread.Condition,
    needs_update: bool,
}{ .mutex = .{}, .condition = .{}, .needs_update = false };
//function to handle signaling the main thread to update
//the texture of the top mathod.
var texture_made_counter: u64 = 0;
fn sendTextureUpdateSignal(comptime single_threaded: bool) void {
    if (single_threaded) {
        UpdateTopTexture();
        return;
    }
    TextureUpdateMut.needs_update = true;
    while (TextureUpdateMut.needs_update) {
        TextureUpdateMut.condition.wait(&TextureUpdateMut.mutex);
    }
}
pub fn clearGarbageTextures() void {
    for (textureGarbage.items) |texture| {
        texture.destroy();
    }
    textureGarbage.clearRetainingCapacity();
}

pub fn reciveTextureUpdateSignal() void {
    TextureUpdateMut.mutex.lock();
    defer TextureUpdateMut.mutex.unlock();
    if (TextureUpdateMut.needs_update) {
        UpdateTopTexture();
        TextureUpdateMut.needs_update = false;
        TextureUpdateMut.condition.signal();
    }
}

fn UpdateTopTexture() void {
    if (stack.last) |top_method| {
        top_method.data.makeTexture(app.renderer) catch unreachable;
    }
}

//-----------------------------------------------------------------------

pub fn fmtz(args: anytype, allocator: std.mem.Allocator) [:0]u8 {
    return std.fmt.allocPrintZ(allocator, "fn ({any})", .{args}) catch unreachable;
}

pub fn Method(comptime args_type: type) type {
    //, function: fn (args_type) i64
    return struct {
        const Self = @This();
        args: args_type,
        pub fn fmt(self: Self, allocator: std.mem.Allocator) []u8 {
            return std.fmt.allocPrint(allocator, "fn ({any})", .{self.args}) catch unreachable;
        }
        pub fn fmtZ(self: Self, allocator: std.mem.Allocator) [:0]u8 {
            return std.fmt.allocPrintZ(allocator, "fn ({any})", .{self.args}) catch unreachable;
        }
        fn makeTexture(self: *Method, renderer: SDL.Renderer) !void {
            if (self.texture) |texture| {
                textureGarbage.append(texture) catch unreachable;
                self.texture = null;
            }
            const last_target = renderer.getTarget();

            const text =
                if (top_eval) |eval| std.fmt.allocPrintZ(app.Allocator.allocator(), "{d}", .{eval}) catch unreachable else self.fmtZ(app.Allocator.allocator());
            defer app.Allocator.allocator().free(text);
            const texture = try SDLex.cloneTexture(design.method.bg, renderer);
            //copy design texture
            try renderer.setTarget(texture);
            try renderer.copy(design.method.bg, null, null);
            //create text texture and place it on copy
            const text_texture = SDLex.textureFromText(text, design.font, design.method.fg, renderer);
            const text_size: SDL.Size = .{ .width = @intCast(40 * text.len), .height = 250 };
            const info = try texture.query();
            const text_rect = SDLex.alignedRect(SDL.Rectangle{ .x = 0, .y = 0, .width = @intCast(info.width), .height = @intCast(info.height) }, .{ .x = 0.5, .y = 0.5 }, text_size);
            try renderer.copy(text_texture, text_rect, null);
            self.texture = texture;
            texture_made_counter += 1;
            try renderer.setTarget(last_target);
        }
        fn destroyTexture(self: *Method) void {
            if (self.texture) |tex| {
                const save_tex = tex;
                self.texture = null;
                save_tex.destroy();
            }
        }
        pub fn getData(self: Self, allocator: std.mem.Allocator) MethodData {
            return .{ .signiture = self.fmtZ(allocator), .texture = if (self.texture) |texture| texture else self.makeTexture(app.renderer) };
        }
    };
}

//data to save function data to use in visualization later.
pub const MethodData = struct {
    signiture: [:0]u8,
    texture: ?SDL.Texture,
    const Self = @This();
    fn makeTexture(self: *Self, renderer: SDL.Renderer) !void {
        if (self.texture) |texture| {
            try textureGarbage.append(texture);
            self.texture = null;
        }
        const last_target = renderer.getTarget();
        const texture = try SDLex.cloneTexture(design.method.bg, renderer);
        //copy design texture
        try renderer.setTarget(texture);
        try renderer.copy(design.method.bg, null, null);
        //create text texture and place it on copy
        const text =
            if (top_eval) |eval| std.fmt.allocPrintZ(app.Allocator.allocator(), "{d}", .{eval}) catch unreachable else self.signiture;
        const text_texture = SDLex.textureFromText(text, design.font, design.method.fg, renderer);
        const text_size: SDL.Size = .{ .width = @intCast(40 * text.len), .height = 250 };
        const info = try texture.query();
        const text_rect = SDLex.alignedRect(SDL.Rectangle{ .x = 0, .y = 0, .width = @intCast(info.width), .height = @intCast(info.height) }, .{ .x = 0.5, .y = 0.5 }, text_size);
        try renderer.copy(text_texture, text_rect, null);
        self.texture = texture;
        texture_made_counter += 1;
        try renderer.setTarget(last_target);
    }
};

pub fn push(allocator: std.mem.Allocator, method: MethodData) void {
    TextureUpdateMut.mutex.lock();
    defer TextureUpdateMut.mutex.unlock();
    const node = allocator.create(std.DoublyLinkedList(MethodData).Node) catch unreachable;
    node.data = method;
    stack.append(node);
    sendTextureUpdateSignal(app.single_threaded);
}
pub fn pop(allocator: std.mem.Allocator) void {
    TextureUpdateMut.mutex.lock();
    defer TextureUpdateMut.mutex.unlock();
    if (stack.pop()) |last| {
        if (last.data.texture) |texture| {
            textureGarbage.append(texture) catch unreachable;
        }
        allocator.destroy(last);
        top_eval = null;
    }
}

pub fn draw(renderer: SDL.Renderer, view: View) void {
    view.draw(SDLex.convertSDLRect(design.frame.rect), design.frame.texture, app.renderer);

    var it = stack.first;
    var currentY = design.position.y;
    var idx: usize = 0;
    while (it) |node| : ({
        it = node.next;
        currentY -= design.method.size.height;
    }) {
        idx += 1;
        if (node.data.texture) |texture| {
            const rect = view.convert(SDLex.convertSDLRect(SDL.Rectangle{ .x = design.position.x, .y = currentY, .width = design.method.size.width, .height = design.method.size.height })) catch continue;
            renderer.copy(texture, SDLex.convertSDLRect(rect), null) catch unreachable;
        }
    }
}

pub fn evalTop(value: i64) void {
    TextureUpdateMut.mutex.lock();
    defer TextureUpdateMut.mutex.unlock();
    if (stack.last) |_| {
        top_eval = value;
        sendTextureUpdateSignal(app.single_threaded);
    }
}

pub fn forgetEval() void {
    TextureUpdateMut.mutex.lock();
    defer TextureUpdateMut.mutex.unlock();
    if (stack.last) |top| {
        _ = top;
        top_eval = null;
        sendTextureUpdateSignal(app.single_threaded);
    }
}
