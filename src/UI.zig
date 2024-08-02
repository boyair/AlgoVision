const SDL = @import("sdl2");
const SDLex = @import("SDLex.zig");
const std = @import("std");
const Action = @import("action.zig");
const Design = @import("design.zig").UI;
var owner_renderer: SDL.Renderer = undefined;

pub fn init(renderer: SDL.Renderer) !void {
    owner_renderer = renderer;
    try speed_element.updateTexture(1.0);
    try action_element.updateTexture(Action.actions.none);
    try freecam_element.updateTexture(false);
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
            Design.view.draw(SDLex.convertSDLRect(self.design.rect), self.texture, owner_renderer);
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
    };
}

pub var speed_element = uiElement(f128, printSpeed){ .texture = undefined, .cache = 1.0, .design = &Design.speed };
fn printSpeed(buf: []u8, speed: f128) [:0]u8 {
    return std.fmt.bufPrintZ(buf, "speed: {d:.2}", .{speed}) catch unreachable;
}

pub var action_element = uiElement(Action.actions, printAction){ .texture = undefined, .cache = undefined, .design = &Design.action };
fn printAction(buf: []u8, action: Action.actions) [:0]u8 {
    return std.fmt.bufPrintZ(buf, "action: {s:<16}", .{@tagName(action)}) catch unreachable;
}
fn printFreeCam(buf: []u8, on: bool) [:0]u8 {
    return std.fmt.bufPrintZ(buf, "freecam: {s:<16}", .{if (on) "On" else "Off"}) catch unreachable;
}

pub var freecam_element = uiElement(bool, printFreeCam){ .texture = undefined, .cache = false, .design = &Design.freecam };

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
