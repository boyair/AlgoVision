const SDL = @import("sdl2");
const std = @import("std");
const Action = @import("action.zig").Action;
const design = @import("design.zig").UI;
var owner_renderer: SDL.Renderer = undefined;

pub fn init(renderer: SDL.Renderer) !void {
    owner_renderer = renderer;
    try updateTexSpeed(1.0);
}

// speed view
var speed_tex: SDL.Texture = undefined;
var speed_cache: f128 = 1.0;
pub fn drawSpeed(speed: f128) !void {
    //only update texture if speed value changed
    if (speed != speed_cache) {
        updateTexSpeed(speed) catch {
            @panic("failed to recreate ui element: speed");
        };
        speed_cache = speed;
    }
    try owner_renderer.copy(speed_tex, design.speed.rect, null);
}

pub fn scrollForSpeed(speed: *f128, scroll_delta: i32, mouse_pos: SDL.Point) bool {
    if (SDL.c.SDL_PointInRect(@ptrCast(&mouse_pos), @ptrCast(&design.speed.rect)) == SDL.c.SDL_TRUE) {
        speed.* *= (1.0 + @as(f128, @floatFromInt(scroll_delta)) / 10.0);
        speed.* = @min(10.0, speed.*);
        speed.* = @max(0.2, speed.*);
        return true;
    }
    return false;
}

fn updateTexSpeed(speed: f128) !void {
    var text_buffer: [12]u8 = undefined;
    const num_str = std.fmt.bufPrintZ(&text_buffer, "X {d:.2}", .{speed}) catch "???";
    const surf = design.font.renderTextBlended(num_str, design.speed.fg) catch handle: {
        std.debug.print("failed to load surface for texture\npossible used bad font.\n", .{});
        break :handle SDL.createRgbSurfaceWithFormat(32, 32, SDL.PixelFormatEnum.rgba8888) catch unreachable;
    };
    speed_tex = try SDL.createTextureFromSurface(owner_renderer, surf);
    try speed_tex.setBlendMode(.blend);
    surf.destroy();
}

//action viewer
var action_tex: SDL.Texture = undefined;
var action_cache: Action = .{ .none = {} };

pub fn drawAction(action: Action) !void {
    if (@intFromEnum(action) != @intFromEnum(action_cache)) {
        updateTexAction(action) catch {
            @panic("failed to create texture: action");
        };
    }
    try owner_renderer.copy(action_tex, design.action.rect, null);
}

fn updateTexAction(action: Action) !void {
    var text_buffer: [20]u8 = undefined;
    const num_str = std.fmt.bufPrintZ(&text_buffer, "{s}", .{@tagName(action)}) catch "???";
    const surf = design.font.renderTextBlended(num_str, design.action.fg) catch handle: {
        std.debug.print("failed to load surface for texture\npossible used bad font.\n", .{});
        break :handle SDL.createRgbSurfaceWithFormat(32, 32, SDL.PixelFormatEnum.rgba8888) catch unreachable;
    };
    action_tex = try SDL.createTextureFromSurface(owner_renderer, surf);
    try action_tex.setBlendMode(.blend);
    surf.destroy();
}
