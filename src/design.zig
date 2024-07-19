const SDL = @import("sdl2");
pub var BG_color: SDL.Color = SDL.Color.rgb(90, 90, 90);

pub const heap = struct {
    pub var font: SDL.ttf.Font = undefined;

    pub const block = struct {
        pub const size: SDL.Size = .{ .width = 100, .height = 100 };
        pub const padding: SDL.Size = .{ .width = 12, .height = 12 };
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
        pub const user = struct {
            pub const fg: SDL.Color = SDL.Color.red;
            pub const bg: SDL.Color = SDL.Color.blue;
        };
    };
    pub const position: SDL.Point = .{ .x = -100, .y = -300 };
};

pub const UI = struct {
    pub var font: SDL.ttf.Font = undefined;
    pub const bg = SDL.Color.black;
    pub const element = struct {
        rect: SDL.Rectangle,
        fg: SDL.Color,
        bg: SDL.Color,
    };
    pub const speed = element{
        .rect = .{ .x = 0, .y = 0, .width = 130, .height = 100 },
        .fg = SDL.Color.white,
        .bg = SDL.Color.rgba(0, 0, 0, 255),
    };
    pub const action = element{
        .rect = .{ .x = 400, .y = 0, .width = 200, .height = 100 },
        .fg = SDL.Color.rgb(200, 200, 0),
        .bg = SDL.Color.rgba(0, 0, 0, 255),
    };
};
