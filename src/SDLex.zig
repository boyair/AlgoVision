const dprint = @import("std").debug.print;
const SDL = @import("sdl2");
const Vec2 = @import("Vec2.zig").Vec2;
const os = @import("builtin").os;

pub fn fullyInitSDL() !void {

    // prefer wayland over x11 when on linux
    if (os.tag == .linux) {
        if (!SDL.setHint("SDL_VIDEODRIVER", "wayland,x11")) {
            dprint("failed to hint wayland to sdl!!", .{});
            return SDL.Error.SdlError;
        }
    }
    //init SDL
    try SDL.init(SDL.InitFlags.everything);
    try SDL.ttf.init();
}

pub fn fullyQuitSDL() void {
    SDL.ttf.quit();
    SDL.quit();
}
pub fn conertVecPoint(original: anytype) if (@TypeOf(original) == Vec2) SDL.Point else Vec2 {
    const org_type: type = @TypeOf(original);
    if (org_type == Vec2) {
        return SDL.Point{
            .x = @intFromFloat(original.x),
            .y = @intFromFloat(original.y),
        };
    } else if (org_type == SDL.Point) {
        return Vec2{
            .x = @floatFromInt(original.x),
            .y = @floatFromInt(original.y),
        };
    }
    @compileError("conertVecPoint expects either a point or a vec type\n");
}

pub fn convertSDLRect(original: anytype) if (@TypeOf(original) == SDL.RectangleF) SDL.Rectangle else SDL.RectangleF {
    const org_type = @TypeOf(original);
    if (org_type == SDL.RectangleF) {
        return SDL.Rectangle{
            .x = @intFromFloat(original.x),
            .y = @intFromFloat(original.y),
            .width = @intFromFloat(original.width),
            .height = @intFromFloat(original.height),
        };
    } else if (org_type == SDL.Rectangle) {
        return SDL.RectangleF{
            .x = @floatFromInt(original.x),
            .y = @floatFromInt(original.y),
            .width = @floatFromInt(original.width),
            .height = @floatFromInt(original.height),
        };
    }
    @compileError("ConvertSDLRect expects a rect type\n");
}

pub fn compareRect(rect1: anytype, rect2: anytype) bool {
    return rect1.x == rect2.x and
        rect1.y == rect2.y and
        rect1.width == rect2.width and
        rect1.height == rect2.height;
}
