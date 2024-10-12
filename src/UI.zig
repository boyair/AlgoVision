const SDL = @import("sdl2");
const SDLex = @import("SDLex.zig");
const std = @import("std");
const Action = @import("action.zig");
const Design = @import("design.zig").UI;
var owner_renderer: SDL.Renderer = undefined;

pub fn init(exe_path: []const u8, comptime font_path: []const u8, renderer: SDL.Renderer) !void {
    Design.font = SDLex.loadResource(exe_path, font_path, renderer) catch unreachable;
    owner_renderer = renderer;
    try checkboxTextures.init(exe_path, renderer);
    try speed_element.updateTexture(1.0);
    try action_element.updateTexture(Action.actions.none);
    try freecam_element.updateTexture({});
    try freecam_checkbox.updateTexture(false);
}
pub fn deinit() void {
    if (speed_element.texture) |texture| {
        texture.destroy();
    }
    if (action_element.texture) |texture| {
        texture.destroy();
    }
    if (freecam_element.texture) |texture| {
        texture.destroy();
    }
    if (freecam_checkbox.texture) |texture| {
        texture.destroy();
    }
    checkboxTextures.deinit();
    Design.font.close();
}
fn uiElement(value_type: type, makeTexture: fn (value: value_type) SDL.Texture, eventHandle: ?fn (event: *const SDL.Event, data: *value_type) void) type {
    return struct {
        texture: ?SDL.Texture,
        cache: value_type,
        rect: *const SDL.Rectangle,

        const Self = @This();
        pub fn draw(self: *Self, value: value_type) void {
            if (value != self.cache) {
                self.updateTexture(value) catch unreachable;
                self.cache = value;
            }
            Design.view.draw(SDLex.convertSDLRect(self.rect.*), self.texture.?, owner_renderer);
        }
        pub inline fn handleEvent(self: *Self, event: *const SDL.Event, mouse_pos: SDL.Point, value: *value_type) void {
            if (eventHandle) |handle| {
                if (isHovered(self, mouse_pos)) {
                    handle(event, value);
                }
            }
        }
        pub fn updateTexture(self: *@This(), value: value_type) !void {
            if (self.texture) |prev_tex| {
                prev_tex.destroy();
            }
            self.texture = makeTexture(value);
        }
        pub fn isHovered(self: *const Self, mouse_pos: SDL.Point) bool {
            const converted = Design.view.convert(SDLex.convertSDLRect(self.rect.*)) catch unreachable;
            return SDLex.pointInRect(mouse_pos, SDLex.convertSDLRect(converted));
        }
    };
}
pub fn textElement(value_type: type, print: fn (buf: []u8, val: value_type) [:0]const u8, eventHandle: ?fn (event: *const SDL.Event, data: *value_type) void, design: *const Design.element) type {
    return struct {
        element: uiElement(value_type, makeTexture, eventHandle),

        pub fn init(value: value_type) @This() {
            return .{ .element = .{ .texture = null, .cache = value, .rect = &design.rect } };
        }
        fn makeTexture(value: value_type) SDL.Texture {
            var text_buffer: [40]u8 = undefined;
            const num_str = print(&text_buffer, value);

            const surf = Design.font.renderTextBlended(num_str, design.fg) catch handle: {
                std.debug.print("failed to load surface for texture\npossible used bad font.\n", .{});
                break :handle SDL.createRgbSurfaceWithFormat(32, 32, SDL.PixelFormatEnum.rgba8888) catch unreachable;
            };
            const texture = SDL.createTextureFromSurface(owner_renderer, surf) catch unreachable;
            texture.setBlendMode(.blend) catch unreachable;
            surf.destroy();
            return texture;
        }
    };
}

pub fn checkBoxClick(event: *const SDL.Event, data: *bool) void {
    if (event.* == .mouse_button_up) {
        if (event.mouse_button_up.button == .left) {
            data.* = !data.*;
        }
    }
}

var checkboxTextures = struct {
    enabled: SDL.Texture,
    disabled: SDL.Texture,

    pub fn init(self: *@This(), exe_path: []const u8, renderer: SDL.Renderer) !void {
        self.enabled = try SDLex.loadResource(exe_path, "/textures/V.png", renderer);
        self.disabled = try SDLex.loadResource(exe_path, "/textures/X.png", renderer);
    }
    pub fn deinit(self: *@This()) void {
        self.enabled.destroy();
        self.disabled.destroy();
    }
}{ .enabled = undefined, .disabled = undefined };

fn makeCheckBox(enabled: bool) SDL.Texture {
    const right_texture = if (enabled) checkboxTextures.enabled else checkboxTextures.disabled;
    return SDLex.cloneTexture(right_texture, owner_renderer) catch unreachable;
}
pub const checkbox = uiElement(bool, makeCheckBox, freecamToggle);
pub var freecam_checkbox = checkbox{ .texture = null, .cache = false, .rect = &Design.CBfreecam.rect };

pub var speed_element = textElement(
    f128,
    printSpeed,
    scrollForSpeed,
    &Design.speed,
).init(1.0).element;
fn printSpeed(buf: []u8, speed: f128) [:0]const u8 {
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

pub var action_element = textElement(Action.actions, printAction, null, &Design.action).init(Action.actions.none).element;
fn printAction(buf: []u8, action: Action.actions) [:0]const u8 {
    return std.fmt.bufPrintZ(buf, "action: {s:<16}", .{@tagName(action)}) catch unreachable;
}
fn printFreeCam(buf: []u8, on: void) [:0]const u8 {
    _ = buf;
    _ = on;
    return "freecam";
}

pub var freecam_element = textElement(void, printFreeCam, null, &Design.freecam).init({}).element;

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
    try owner_renderer.setColor(Design.bg);

    try owner_renderer.fillRect(Design.view.port);
    try owner_renderer.setColor(last_color);
}
