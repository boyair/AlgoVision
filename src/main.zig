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
    heap.initRand();
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
        for (heap.mem_tex, 0..) |texture, idx| {
            const column = idx % heap.rows;
            const row = @divFloor(idx, heap.rows);
            const possible_rect = cam_view.convert(.{ .x = @as(f32, @floatFromInt(row)) * 100.0, .y = @as(f32, @floatFromInt(column)) * 100.0, .width = 100, .height = 100 }) catch null;
            if (possible_rect) |rect| {
                try renderer.drawRect(convertSDLRect(rect));
                try renderer.copy(texture, convertSDLRect(rect), null);
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

test "zoom value" {
    try std.testing.expect(@as(f32, @floatFromInt(2000000)) / 100_000_000.0 * (1.5 - 1.1) + 1.0 > 1.0);
}
