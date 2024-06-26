const builtin = @import("builtin");
const std = @import("std");
const SDL = @import("sdl2");
const Vec2 = @import("Vec2.zig").Vec2;
const View = @import("view.zig").View;
const heap = @import("heap.zig");
const convertSDLRect = @import("SDLex.zig").convertSDLRect;

var gpa = std.heap.GeneralPurposeAllocator(.{}){};

pub fn main() !void {
    // prefer wayland over x11 when on linux
    if (builtin.os.tag == .linux) {
        if (!SDL.setHint("SDL_VIDEODRIVER", "wayland,x11")) {
            std.debug.print("failed to hint wayland to sdl!!", .{});
            return SDL.Error.SdlError;
        }
    }
    try SDL.init(SDL.InitFlags.everything);
    defer SDL.quit();
    try SDL.ttf.init();
    defer SDL.ttf.quit();

    var window = try SDL.createWindow(
        "PC Visualliser",
        .{ .centered = {} },
        .{ .centered = {} },
        1000,
        1000,
        .{ .vis = .shown, .resizable = false, .borderless = false, .mouse_capture = true },
    );
    defer window.destroy();

    var renderer = try SDL.createRenderer(window, null, .{ .accelerated = true });
    defer renderer.destroy();
    const font: SDL.ttf.Font = try SDL.ttf.openFont("ioveska.ttf", 100);
    defer font.close();
    const loading: SDL.Surface = font.renderTextSolid("Loading", SDL.Color.white) catch try SDL.createRgbSurfaceWithFormat(32, 32, SDL.PixelFormatEnum.rgb888);
    const loading_tex: SDL.Texture = try SDL.createTextureFromSurface(renderer, loading);
    try renderer.copy(loading_tex, .{ .x = 0, .y = 200, .width = 1000, .height = 600 }, null);
    renderer.present();
    heap.initRand();
    try renderer.setColorRGB(0, 90, 0);
    try heap.initTextures(&font, renderer);
    defer heap.destroyTextures();
    defer window.destroy();

    var cam_view = View.init(&window);

    var last_iteration_duration: i128 = 0;
    var time_left_for_zoom: i128 = 0;
    const frame_time_ns: u64 = 10_000_000;
    var dragging = false;
    mainLoop: while (true) {
        const start_time = std.time.nanoTimestamp();
        const mouse_state = SDL.getMouseState();
        const mouse_pos: SDL.Point = .{ .x = mouse_state.x, .y = mouse_state.y };
        while (SDL.pollEvent()) |ev| {
            switch (ev) {
                .mouse_button_down => {
                    if (ev.mouse_button_down.button == SDL.MouseButton.right) {
                        dragging = true;
                    }
                },
                .mouse_button_up => {
                    if (ev.mouse_button_up.button == SDL.MouseButton.right) {
                        dragging = false;
                    }
                },
                .mouse_wheel => {
                    const delta = ev.mouse_wheel.delta_y;
                    cam_view.zoom(1.0 + @as(f32, @floatFromInt(delta)) / 10.0, mouse_pos);
                },
                .mouse_motion => {
                    if (dragging) {
                        const vec_mouse_delta: Vec2 = .{ .x = @floatFromInt(ev.mouse_motion.delta_x), .y = @floatFromInt(ev.mouse_motion.delta_y) };
                        const scaled_delta: Vec2 = cam_view.scale_vec_port_to_win(vec_mouse_delta);
                        cam_view.port.x -= scaled_delta.x;
                        cam_view.port.y -= scaled_delta.y;
                    }
                },
                .window => {
                    if (ev.window.type == .resized) {
                        cam_view.window_size = window.getSize();
                    }
                },
                .quit => break :mainLoop,
                else => {},
            }
        }

        try renderer.clear();
        try renderer.setColor(SDL.Color.black);

        for (heap.batch_tex, 0..) |row, ir| {
            for (row, 0..) |column, ic| {
                const batch_rectF = cam_view.convert(.{ .x = @floatFromInt(ic * 800), .y = @floatFromInt(ir * 800), .width = 800, .height = 800 }) catch null;
                if (batch_rectF) |rectF| {
                    const rect: SDL.Rectangle = convertSDLRect(rectF);
                    try renderer.copy(column, rect, null);
                }
            }
        }

        try renderer.setColorRGB(0, 90, 0);
        time_left_for_zoom -= last_iteration_duration;
        if (time_left_for_zoom < 0) {
            time_left_for_zoom = 0;
        }
        renderer.present();
        const passed_time = @as(u64, @intCast(std.time.nanoTimestamp() - start_time));
        if (passed_time < frame_time_ns) {
            std.time.sleep(frame_time_ns - passed_time);
        }
        last_iteration_duration = std.time.nanoTimestamp() - start_time;
    }
}
