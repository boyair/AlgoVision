const SDL = @import("sdl2");
pub var BG_color: SDL.Color = SDL.Color.rgb(40, 40, 40);

pub const heap = struct {
    pub var font: SDL.ttf.Font = undefined;

    pub const block = struct {
        pub const size: SDL.Size = .{ .width = 1000, .height = 1000 };
        pub const padding: SDL.Size = .{ .width = 100, .height = 100 };
        pub const full_size: SDL.Size = .{ .width = size.width + padding.width, .height = size.height + padding.height };
        pub const grid_color: SDL.Color = SDL.Color.black;

        pub const free = struct {
            pub const fg: SDL.Color = SDL.Color.green;
            pub const bg: SDL.Color = SDL.Color.white;
        };

        pub const taken = struct {
            pub const fg: SDL.Color = SDL.Color.red;
            pub const bg: SDL.Color = SDL.Color.black;
        };
    };
    pub var color_BG: SDL.Color = SDL.Color.black;
    pub const color_taken: SDL.Color = SDL.Color.red;
    pub const color_free: SDL.Color = SDL.Color.white;
    pub const color_user: SDL.Color = undefined;
    pub const position: SDL.Point = .{ .x = 0, .y = 0 };
    pub const block_size: SDL.Size = .{ .width = 200, .height = 100 };
};
