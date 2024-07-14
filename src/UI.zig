const SDL = @import("sdl2");
const std = @import("std");
const design = @import("design.zig").UI;

pub fn showSpeed(renderer: SDL.Renderer, speed: f128) !void {
    var text_buffer: [12]u8 = undefined;
    const num_str = std.fmt.bufPrintZ(&text_buffer, "X {d:.2}", .{speed}) catch "???";
    const surf = design.font.renderTextBlended(num_str, design.speed.fg) catch handle: {
        std.debug.print("failed to load surface for texture\npossible used bad font.\n", .{});
        break :handle SDL.createRgbSurfaceWithFormat(32, 32, SDL.PixelFormatEnum.rgba8888) catch unreachable;
    };
    const texture = try SDL.createTextureFromSurface(renderer, surf);

    try texture.setBlendMode(.blend);
    try renderer.copy(texture, design.speed.rect, null);
    surf.destroy();
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
