const SDL = @import("sdl2");
const std = @import("std");
const Action = @import("action.zig").Action;
const Design = @import("design.zig").UI;
var owner_renderer: SDL.Renderer = undefined;

pub fn init(renderer: SDL.Renderer) !void {
    owner_renderer = renderer;
    try speed_element.updateTexture(1.0);
    try action_element.updateTexture(@intFromEnum(Action.none));
}
fn uiElement(value_type: type, print: fn (buf: []u8, val: value_type) [:0]u8) type {
    return struct {
        texture: SDL.Texture,
        cache: value_type,
        design: *const Design.element,
        pub fn draw(self: *@This(), value: value_type) void {
            if (value != self.cache) {
                self.updateTexture(value) catch unreachable;
                self.cache = value;
            }
            owner_renderer.copy(self.texture, self.design.rect, null) catch unreachable;
        }
        pub fn updateTexture(self: *@This(), value: value_type) !void {
            var text_buffer: [22]u8 = undefined;
            const num_str = print(&text_buffer, value);

            const surf = Design.font.renderTextBlended(num_str, self.design.fg) catch handle: {
                std.debug.print("failed to load surface for texture\npossible used bad font.\n", .{});
                break :handle SDL.createRgbSurfaceWithFormat(32, 32, SDL.PixelFormatEnum.rgba8888) catch unreachable;
            };
            self.texture = try SDL.createTextureFromSurface(owner_renderer, surf);
            try self.texture.setBlendMode(.blend);
            surf.destroy();
        }
    };
}

fn printSpeed(buf: []u8, speed: f128) [:0]u8 {
    return std.fmt.bufPrintZ(buf, "{d:.2}", .{speed}) catch unreachable;
}
pub var speed_element = uiElement(f128, printSpeed){ .texture = undefined, .cache = 1.0, .design = &Design.speed };

const action_enum = std.meta.FieldEnum(Action);
fn printAction(buf: []u8, action: @typeInfo(action_enum).Enum.tag_type) [:0]u8 {
    const tag: action_enum = @enumFromInt(action);
    return std.fmt.bufPrintZ(buf, "{s}", .{@tagName(tag)}) catch unreachable;
}

pub var action_element = uiElement(@typeInfo(action_enum).Enum.tag_type, printAction){ .texture = undefined, .cache = undefined, .design = &Design.action };

//action viewer
var action_tex: SDL.Texture = undefined;
var action_cache: Action = .{ .none = {} };

pub fn drawAction(action: Action) !void {
    if (@intFromEnum(action) != @intFromEnum(action_cache)) {
        updateTexAction(action) catch {
            @panic("failed to create texture: action");
        };
    }
    try owner_renderer.copy(action_tex, Design.action.rect, null);
}

fn updateTexAction(action: Action) !void {
    var text_buffer: [20]u8 = undefined;
    const num_str = std.fmt.bufPrintZ(&text_buffer, "{s}", .{@tagName(action)}) catch "???";
    const surf = Design.font.renderTextBlended(num_str, Design.action.fg) catch handle: {
        std.debug.print("failed to load surface for texture\npossible used bad font.\n", .{});
        break :handle SDL.createRgbSurfaceWithFormat(32, 32, SDL.PixelFormatEnum.rgba8888) catch unreachable;
    };
    action_tex = try SDL.createTextureFromSurface(owner_renderer, surf);
    try action_tex.setBlendMode(.blend);
    surf.destroy();
}
