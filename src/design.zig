const SDL = @import("sdl2");
pub var BG_color: SDL.Color = SDL.Color.rgb(0, 90, 0);

pub const heap = struct {
    pub var color_BG: SDL.Color = SDL.Color.black;
    pub const color_taken: SDL.Color = SDL.Color.rgb(255, 0, 0);
    pub const color_free: SDL.Color = SDL.Color.rgb(255, 0, 0);
    pub const color_user: SDL.Color = SDL.Color.rgb(255, 0, 0);
    pub const position: SDL.Point = .{ .x = 0, .y = 0 };
    pub const block_size: SDL.Size = .{ .width = 100, .height = 100 };
    pub const padding_size: SDL.Size = .{ .width = 20, .height = 20 };
};
