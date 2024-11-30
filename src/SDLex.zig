const dprint = @import("std").debug.print;
const SDL = @import("SDL");
const sound = @import("sound.zig");
const Vec2 = @import("Vec2.zig").Vec2;
const os = @import("builtin").os;
const std = @import("std");

pub fn fullyInitSDL() !void {

    // prefer wayland over x11 when on linux
    if (os.tag == .linux) {
        if (!SDL.setHint("SDL_VIDEODRIVER", "wayland,x11")) {
            dprint("failed to hint wayland to sdl!!", .{});
            return SDL.Error.SdlError;
        }
    }
    //init SDL
    try SDL.init(SDL.InitFlags.everything);
    try SDL.ttf.init();

    try sound.init();
}

pub fn fullyQuitSDL() void {
    SDL.ttf.quit();
    SDL.quit();
}
pub fn pointInRect(point: SDL.Point, rect: SDL.Rectangle) bool {
    return point.x > rect.x and point.x < rect.x + rect.width and
        point.y > rect.y and point.y < rect.y + rect.height;
}

pub fn loadResource(exe_path: []const u8, comptime relative_path: []const u8, renderer: ?SDL.Renderer) !resourceType(relative_path) {
    var full_path_buf: [120]u8 = undefined;
    const full_path = std.fmt.bufPrintZ(&full_path_buf, "{s}{s}", .{ exe_path, relative_path }) catch unreachable;
    switch (resourceType(relative_path)) {
        SDL.Texture => {
            return SDL.image.loadTexture(renderer.?, full_path);
        },
        SDL.ttf.Font => {
            return SDL.ttf.openFont(full_path, 150);
        },
        sound.Wav => {
            return sound.Wav.init(full_path);
        },
        else => {
            @compileError("got unknown resource type");
        },
    }
}

fn resourceType(comptime path: []const u8) type {
    if (path.len < 4)
        @compileError("resource path too short to exist");

    const format = path[(path.len - 4)..]; // last 4 characters
    if (std.mem.eql(u8, format, ".png")) {
        return SDL.Texture;
    } else if (std.mem.eql(u8, format, ".ttf")) {
        return SDL.ttf.Font;
    } else if (std.mem.eql(u8, format, ".wav")) {
        return sound.Wav;
    }
    @compileLog(format);

    @compileError("tried to load an unknown resource!");
}

pub fn alignedRect(rect: anytype, alignment: Vec2, size: anytype) @TypeOf(rect) {
    if (@TypeOf(rect) == SDL.Rectangle) {
        if (@TypeOf(size) != SDL.Size)
            @compileError("size type for SDL Rectangle must be SDL Size.");
        return SDL.Rectangle{
            .x = rect.x + @as(c_int, @intFromFloat(@as(f32, @floatFromInt(rect.width)) * alignment.x)) - @divExact(size.width, 2),
            .y = rect.y + @as(c_int, @intFromFloat(@as(f32, @floatFromInt(rect.height)) * alignment.y)) - @divExact(size.height, 2),
            .width = size.width,
            .height = size.height,
        };
    } else if (@TypeOf(rect) == SDL.RectangleF) {
        if (@TypeOf(size) != Vec2)
            @compileError("size type for SDL RectangleF must be Vec2.");
        return SDL.RectangleF{
            .x = rect.x + (rect.width * alignment.x) - (size.x / 2.0),
            .y = rect.y + (rect.height * alignment.y) - (size.y / 2.0),
            .width = size.x,
            .height = size.y,
        };
    }
    @compileError("a rectangle type must be passed for the rect argument");
}

pub inline fn textureFromText(text: [:0]const u8, font: SDL.ttf.Font, color: SDL.Color, renderer: SDL.Renderer) SDL.Texture {
    const surf = font.renderTextBlended(text, color) catch {
        if (text.len == 0) {
            return SDL.createTexture(renderer, SDL.Texture.Format.bgra8888, .target, 32, 32) catch unreachable;
        } else {
            @panic("failed to load surface from font\nmight be caused by font error font.\n");
        }
    };
    return SDL.createTextureFromSurface(renderer, surf) catch unreachable;
}

pub fn conertVecPoint(original: anytype) if (@TypeOf(original) == Vec2) SDL.Point else Vec2 {
    const org_type: type = @TypeOf(original);
    if (org_type == Vec2) {
        return SDL.Point{
            .x = @intFromFloat(original.x),
            .y = @intFromFloat(original.y),
        };
    } else if (org_type == SDL.Point) {
        return Vec2{
            .x = @floatFromInt(original.x),
            .y = @floatFromInt(original.y),
        };
    }
    @compileError("conertVecPoint expects either a point or a vec type\n");
}

pub fn convertSDLRect(original: anytype) if (@TypeOf(original) == SDL.RectangleF) SDL.Rectangle else SDL.RectangleF {
    const org_type = @TypeOf(original);
    if (org_type == SDL.RectangleF) {
        return SDL.Rectangle{
            .x = @intFromFloat(original.x),
            .y = @intFromFloat(original.y),
            .width = @intFromFloat(original.width),
            .height = @intFromFloat(original.height),
        };
    } else if (org_type == SDL.Rectangle) {
        return SDL.RectangleF{
            .x = @floatFromInt(original.x),
            .y = @floatFromInt(original.y),
            .width = @floatFromInt(original.width),
            .height = @floatFromInt(original.height),
        };
    }
    @compileLog("type: {}", org_type);
    @compileError("ConvertSDLRect expects a rect type\n");
}
pub fn cloneTexture(original: SDL.Texture, renderer: SDL.Renderer) !SDL.Texture {
    //create new texture with the same properties
    const info = try original.query();
    const new_tex: SDL.Texture = try SDL.createTexture(renderer, info.format, .target, info.width, info.height);
    //save renderer target to avoid harming the regular use of it
    const last_renderer_target = renderer.getTarget();
    try renderer.setTarget(new_tex);
    //copy the texture
    try renderer.copy(original, null, null);
    try new_tex.setBlendMode(try original.getBlendMode());
    //revert renderer to prev target
    try renderer.setTarget(last_renderer_target);
    return new_tex;
}

pub fn compareRect(rect1: anytype, rect2: anytype) bool {
    return rect1.x == rect2.x and
        rect1.y == rect2.y and
        rect1.width == rect2.width and
        rect1.height == rect2.height;
}
