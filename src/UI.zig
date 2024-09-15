const SDL = @import("sdl2");
const SDLex = @import("SDLex.zig");
const std = @import("std");
const Action = @import("action.zig");
const Design = @import("design.zig").UI;
var owner_renderer: SDL.Renderer = undefined;

pub fn init(renderer: SDL.Renderer, exe_path: []const u8, comptime font_path: []const u8) !void {
    Design.font = SDLex.loadResource(exe_path, font_path, renderer) catch unreachable;
    owner_renderer = renderer;
    try speed_element.updateTexture(1.0);
    try action_element.updateTexture(Action.actions.none);
    try freecam_element.updateTexture(false);
}
fn uiElement(value_type: type, print: fn (buf: []u8, val: value_type) [:0]u8, eventHandle: ?fn (event: *const SDL.Event, data: *value_type) void) type {
    return struct {
        texture: SDL.Texture,
        cache: value_type,
        design: *const Design.element,

        const Self = @This();
        pub fn draw(self: *Self, value: value_type) void {
            if (value != self.cache) {
                self.updateTexture(value) catch unreachable;
                self.cache = value;
            }
            Design.view.draw(SDLex.convertSDLRect(self.design.rect), self.texture, owner_renderer);
        }
        pub inline fn handleEvent(self: *Self, event: *const SDL.Event, mouse_pos: SDL.Point, value: *value_type) void {
            if (eventHandle) |handle| {
                if (isHovered(self, mouse_pos)) {
                    handle(event, value);
                }
            }
        }
        pub fn updateTexture(self: *@This(), value: value_type) !void {
            var text_buffer: [40]u8 = undefined;
            const num_str = print(&text_buffer, value);

            const surf = Design.font.renderTextBlended(num_str, self.design.fg) catch handle: {
                std.debug.print("failed to load surface for texture\npossible used bad font.\n", .{});
                break :handle SDL.createRgbSurfaceWithFormat(32, 32, SDL.PixelFormatEnum.rgba8888) catch unreachable;
            };
            self.texture = try SDL.createTextureFromSurface(owner_renderer, surf);
            try self.texture.setBlendMode(.blend);
            surf.destroy();
        }
        pub fn isHovered(self: *const Self, mouse_pos: SDL.Point) bool {
            const converted = Design.view.convert(SDLex.convertSDLRect(self.design.rect)) catch unreachable;
            return SDLex.pointInRect(mouse_pos, SDLex.convertSDLRect(converted));
        }
    };
}

pub var speed_element = uiElement(f128, printSpeed, scrollForSpeed){ .texture = undefined, .cache = 1.0, .design = &Design.speed };
fn printSpeed(buf: []u8, speed: f128) [:0]u8 {
    return std.fmt.bufPrintZ(buf, "speed: {d:.2} {s:>8}", .{ speed, if (speed == 0) "(paused)" else "" }) catch unreachable;
}
pub fn scrollForSpeed(event: *const SDL.Event, data: *f128) void {
    if (event.* == .mouse_wheel and data.* != 0) {
        const scroll_delta = event.mouse_wheel.delta_y;
        data.* *= (1.0 + @as(f128, @floatFromInt(scroll_delta)) / 10.0);
        data.* = @min(10.0, data.*);
        data.* = @max(0.2, data.*);
    }
    if (event.* == .mouse_button_up) {
        if (event.mouse_button_up.button == .left) {
            data.* = if (data.* == 0) 1 else 0;
        }
    }
}

pub var action_element = uiElement(
    Action.actions,
    printAction,
    null,
){ .texture = undefined, .cache = undefined, .design = &Design.action };
fn printAction(buf: []u8, action: Action.actions) [:0]u8 {
    return std.fmt.bufPrintZ(buf, "action: {s:<16}", .{@tagName(action)}) catch unreachable;
}
fn printFreeCam(buf: []u8, on: bool) [:0]u8 {
    return std.fmt.bufPrintZ(buf, "freecam: {s:<16}", .{if (on) "V" else "X"}) catch unreachable;
}

pub var freecam_element = uiElement(bool, printFreeCam, freecamToggle){ .texture = undefined, .cache = false, .design = &Design.freecam };

pub fn freecamToggle(event: *const SDL.Event, data: *bool) void {
    if (event.* == .mouse_button_up and event.mouse_button_up.button == .left) {
        data.* = !data.*;
    }
}
//---------------------------------------------------
//---------------------------------------------------
//-------------------GENERAL UI----------------------
//---------------------------------------------------
//---------------------------------------------------
pub fn drawBG() !void {
    const last_color = try owner_renderer.getColor();
    try owner_renderer.setColor(SDL.Color.black);

    try owner_renderer.fillRect(Design.view.port);
    try owner_renderer.setColor(last_color);
}
