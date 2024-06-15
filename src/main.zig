const std = @import("std");
const builtin = @import("builtin");
const SDL = @import("sdl2"); // Created in build.zig by using exe.root_module.addImport("sdl2", sdk.getWrapperModule());

const View = struct {
    port: SDL.RectangleF,
    owner: *SDL.Window,

    fn init(window: *SDL.Window) View {
        const window_size: SDL.Size = window.getSize();
        return .{
            .port = .{ .x = 0, .y = 0, .width = @floatFromInt(window_size.width), .height = @floatFromInt(window_size.height) },
            .owner = window,
        };
    }
};

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
    var window = try SDL.createWindow(
        "PC Visualliser",
        .{ .centered = {} },
        .{ .centered = {} },
        1000,
        1000,
        .{ .vis = .shown, .resizable = true },
    );
    defer window.destroy();
    var renderer = try SDL.createRenderer(window, null, .{ .accelerated = true });
    defer renderer.destroy();
    const cam_view = View.init(&window);
    std.debug.print("{d} {d} {d} {d}", cam_view.port);
    mainLoop: while (true) {
        while (SDL.pollEvent()) |ev| {
            switch (ev) {
                .quit => break :mainLoop,
                else => {},
            }
        }

        try renderer.setColorRGB(0xF7, 0xA4, 0x1D);
        try renderer.clear();

        renderer.present();
    }
}
