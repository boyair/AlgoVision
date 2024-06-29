const std = @import("std");
const SDL = @import("sdl2");
const Vec2 = @import("Vec2.zig").Vec2;
const View = @import("view.zig").View;
const heap = @import("heap.zig");
const SDLex = @import("SDLex.zig");
const ZoomAnimation = @import("animation.zig").ZoomAnimation;
const design = @import("design.zig");
const convertSDLRect = SDLex
    .convertSDLRect;

var gpa = std.heap.GeneralPurposeAllocator(.{}){};

pub fn main() !void {
    try SDLex.fullyInitSDL();
    defer SDLex.fullyQuitSDL();

    var window = try SDL.createWindow(
        "PC Visualliser",
        .{ .centered = {} },
        .{ .centered = {} },
        1000,
        1000,
        .{ .vis = .shown, .resizable = false, .borderless = false, .mouse_capture = true },
    );
    defer window.destroy();

    const app_dir = try std.fs.selfExeDirPathAlloc(gpa.allocator());
    defer gpa.allocator().free(app_dir);
    const font_name = "/ioveska.ttf";
    const font_path_length = app_dir.len + font_name.len;

    var font_path: []u8 = try gpa.allocator().alloc(u8, font_path_length + 1);
    defer gpa.allocator().free(font_path);

    @memcpy(font_path[0..app_dir.len], app_dir);
    @memcpy(font_path[app_dir.len..font_path_length], font_name);
    font_path[font_path.len - 1] = 0;
    const font_path_nul: [:0]u8 = font_path[0..font_path_length :0];
    std.debug.print("{s}\n", .{font_path_nul});
    var renderer = try SDL.createRenderer(window, null, .{ .accelerated = true });
    defer renderer.destroy();
    const font: SDL.ttf.Font = try SDL.ttf.openFont(font_path_nul, 100);
    defer font.close();
    const loading: SDL.Surface = font.renderTextSolid("Loading", SDL.Color.white) catch try SDL.createRgbSurfaceWithFormat(32, 32, SDL.PixelFormatEnum.rgb888);
    const loading_tex: SDL.Texture = try SDL.createTextureFromSurface(renderer, loading);
    defer loading_tex.destroy();
    loading.destroy();
    try renderer.copy(loading_tex, .{ .x = 0, .y = 200, .width = 1000, .height = 600 }, null);
    renderer.present();
    heap.initIndex();
    const my_mem = heap.alloc(6) catch null;
    if (my_mem) |valid_mem| {
        for (valid_mem) |mem| {
            std.debug.print("{d}\n", .{mem});
        }
    }

    try heap.initTextures(&font, renderer);
    defer heap.destroyTextures();

    var cam_view = View.init(&window);
    var animation: ZoomAnimation = ZoomAnimation.init(cam_view.port, cam_view.port, 0);
    var last_iteration_duration: i128 = 0;
    var time_left_for_zoom: i128 = 0;
    const frame_time_ns: u64 = 10_000_000;
    var dragging = false;
    try renderer.setColor(design.BG_color);
    mainLoop: while (true) {
        const start_time = std.time.nanoTimestamp();
        const mouse_state = SDL.getMouseState();
        const mouse_pos: SDL.Point = .{ .x = mouse_state.x, .y = mouse_state.y };
        if (!animation.done)
            cam_view.port = animation.update(last_iteration_duration);
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
                    const delta: f32 = @floatFromInt(ev.mouse_wheel.delta_y);

                    if (delta != 0)
                        animation = ZoomAnimation.init(cam_view.port, cam_view.getZoomed(1.0 + delta / 2.0, mouse_pos), 200_000_000);
                },
                .mouse_motion => {
                    if (dragging and animation.done) {
                        const vec_mouse_delta: Vec2 = .{ .x = @floatFromInt(ev.mouse_motion.delta_x), .y = @floatFromInt(ev.mouse_motion.delta_y) };
                        const scaled_delta: Vec2 = cam_view.scale_vec_port_to_win(vec_mouse_delta);
                        cam_view.port.x -= scaled_delta.x;
                        cam_view.port.y -= scaled_delta.y;
                        //handle drag during zoom animation.
                        animation.start_state.x = cam_view.port.x;
                        animation.start_state.y = cam_view.port.y;
                        animation.end_state.x = cam_view.port.x;
                        animation.end_state.y = cam_view.port.y;
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

        heap.draw(renderer, cam_view);

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

//TODO:
//add ability to get/set a value from the heap
