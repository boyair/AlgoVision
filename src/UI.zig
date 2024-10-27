const SDL = @import("sdl2");
const SDLex = @import("SDLex.zig");
const std = @import("std");
const App = @import("app.zig");
const Action = @import("action.zig");
const Design = @import("design.zig").UI;
var owner_renderer: SDL.Renderer = undefined;

pub fn init(exe_path: []const u8, comptime font_path: []const u8, renderer: SDL.Renderer) !void {
    Design.font = SDLex.loadResource(exe_path, font_path, renderer) catch unreachable;
    owner_renderer = renderer;
    try checkboxTextures.init(exe_path, renderer);
    try exit_button.updateTexture(true);
    try speed_element.updateTexture(1.0);
    try action_element.updateTexture(Action.actions.none);
    try action_back.updateTexture(false);
    try action_forward.updateTexture(true);
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
pub fn textElement(value_type: type, print: fn (buf: []u8, val: value_type) [:0]const u8, eventHandle: ?fn (event: *const SDL.Event, data: *value_type) void, color: SDL.Color) type {
    return struct {
        element: uiElement(value_type, makeTexture, eventHandle),

        pub fn init(value: value_type, rect: SDL.Rectangle) @This() {
            return .{ .element = .{ .texture = null, .cache = value, .rect = &rect } };
        }
        fn makeTexture(value: value_type) SDL.Texture {
            var text_buffer: [40]u8 = undefined;
            const num_str = print(&text_buffer, value);

            const surf = Design.font.renderTextBlended(num_str, color) catch handle: {
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

pub var exit_button = uiElement(bool, exitButtonTexture, stopRunning){ .texture = null, .cache = false, .rect = &Design.exit_button };
fn exitButtonTexture(running: bool) SDL.Texture {
    _ = running;
    return SDLex.cloneTexture(checkboxTextures.disabled, owner_renderer) catch unreachable;
}
fn stopRunning(event: *const SDL.Event, running: *bool) void {
    if (event.* == .mouse_button_up and event.mouse_button_up.button == .left) {
        running.* = false;
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

pub const checkbox = uiElement(bool, makeCheckBox, freecamToggle);
fn makeCheckBox(enabled: bool) SDL.Texture {
    const right_texture = if (enabled) checkboxTextures.enabled else checkboxTextures.disabled;
    return SDLex.cloneTexture(right_texture, owner_renderer) catch unreachable;
}

pub fn checkBoxClick(event: *const SDL.Event, data: *bool) void {
    if (event.* == .mouse_button_up) {
        if (event.mouse_button_up.button == .left) {
            data.* = !data.*;
        }
    }
}
pub var speed_element = textElement(
    f128,
    printSpeed,
    scrollForSpeed,
    Design.speed.color,
).init(1.0, Design.speed.rect).element;
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

pub var action_element = textElement(Action.actions, printAction, null, Design.action.color).init(Action.actions.none, Design.action.rect).element;
//returns an appropriate name for each action to be displayed.
fn actionNames(action: Action.actions) []const u8 {
    return switch (action) {
        .set_value_heap => "Set value",
        .search => "Search",
        .allocate => "Allocate",
        .free => "Free",
        .print => "Print",
        .call => "Call",
        .eval_function => "Evaluate",
        .forget_eval => "Forget",
        .stack_pop => "Pop",
        .stack_unpop => "Push",
        .none => "None",
    };
}

fn printAction(buf: []u8, action: Action.actions) [:0]const u8 {
    //_ = action;
    var full_text_buf: [40]u8 = undefined;
    const full_text = std.fmt.bufPrintZ(&full_text_buf, "action: {s}", .{actionNames(action)}) catch unreachable;
    return std.fmt.bufPrintZ(buf, "{s:^24}", .{full_text}) catch unreachable;
}
pub const action_arrow = textElement(bool, printArrow, actionArrow, Design.action_arrow_back.color);
fn printArrow(buf: []u8, is_forward: bool) [:0]const u8 {
    _ = buf;
    return if (is_forward) ">" else "<";
}
fn actionArrow(event: *const SDL.Event, is_forward: *bool) void {
    if (event.* == .mouse_button_up and event.mouse_button_up.button == .left) {
        if (is_forward.*) {
            App.operation_manager.fastForward();
        } else {
            App.operation_manager.undoLast();
        }
    }
}
pub var action_back = action_arrow.init(false, Design.action_arrow_back.rect).element;
pub var action_forward = action_arrow.init(true, Design.action_arrow_forward.rect).element;

pub var freecam_element = textElement(void, printFreeCam, null, Design.freecam.color).init({}, Design.freecam.rect).element;
fn printFreeCam(buf: []u8, on: void) [:0]const u8 {
    _ = buf;
    _ = on;
    return "freecam";
}

pub var freecam_checkbox = checkbox{ .texture = null, .cache = false, .rect = &Design.CBfreecam };

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
