const SDL = @import("sdl2");
pub var BG_color: SDL.Color = SDL.Color.rgb(0, 90, 0);

pub const heap = packed struct {
    pub var font: SDL.ttf.Font = undefined;
    pub var color_BG: SDL.Color = SDL.Color.black;
    pub const color_taken: SDL.Color = SDL.Color.rgb(255, 0, 0);
    pub const color_free: SDL.Color = SDL.Color.rgb(255, 0, 0);
    pub const color_user: SDL.Color = SDL.Color.rgb(255, 0, 0);
    pub const position: SDL.Point = .{ .x = 0, .y = 0 };
    pub const block_size: SDL.Size = .{ .width = 100, .height = 100 };
    pub const padding_size: SDL.Size = .{ .width = 20, .height = 20 };
    pub const full_block_size: SDL.Size = .{ .width = block_size.width + padding_size.width, .height = block_size.height + padding_size.height };
};
