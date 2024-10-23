const SDL = @import("sdl2");
const View = @import("view.zig").View;
pub var BG_color: SDL.Color = SDL.Color.rgb(90, 90, 90);
pub const FPS = 144;
pub const frame_time = 1_000_000_000 / FPS;

pub const heap = struct {
    //defined in heap init function
    pub var font: SDL.ttf.Font = undefined;

    pub const block = struct {
        pub const size: SDL.Size = .{ .width = 100, .height = 100 };
        pub const padding: SDL.Size = .{ .width = 12, .height = 12 };
        pub const full_size: SDL.Size = .{ .width = size.width + padding.width, .height = size.height + padding.height };
        pub const grid_color: SDL.Color = SDL.Color.black;
        pub const Colors = struct {
            fg: SDL.Color,
            bg: SDL.Color,
        };

        pub const free = Colors{ .fg = SDL.Color.green, .bg = SDL.Color.white };
        pub const taken = Colors{ .fg = SDL.Color.red, .bg = SDL.Color.black };
        pub const user = Colors{ .fg = SDL.Color.red, .bg = SDL.Color.blue };
    };
    pub const position: SDL.Point = .{ .x = -100, .y = -300 };
};

pub const UI = struct {
    //defined in UI init function
    pub var font: SDL.ttf.Font = undefined;

    pub const bg = SDL.Color.black;
    pub const width_portion = 0.25; // the part of the screen dedicated for the ui

    //defined in app init function based on screen resolution and width_portion
    pub var view: View = undefined;

    pub const element = struct {
        rect: SDL.Rectangle,
        color: SDL.Color,
    };
    pub const speed = element{
        .rect = .{ .x = 20, .y = 0, .width = 350, .height = 75 },
        .color = SDL.Color.white,
    };
    pub const action = element{
        .rect = .{ .x = 20, .y = 100, .width = 350, .height = 75 },
        .color = SDL.Color.white,
    };
    pub const action_arrow_forward = element{
        .rect = .{ .x = 370, .y = 100, .width = 20, .height = 75 },
        .color = SDL.Color.green,
    };
    pub const action_arrow_back = element{
        .rect = .{ .x = 0, .y = 100, .width = 20, .height = 75 },
        .color = SDL.Color.green,
    };
    pub const freecam = element{
        .rect = .{ .x = 100, .y = 200, .width = 200, .height = 65 },
        .color = SDL.Color.white,
    };
    pub var CBfreecam = SDL.Rectangle{ .x = 25, .y = 210, .width = 45, .height = 45 };
};

pub const stack = struct {
    //defined in stack init function
    pub var font: SDL.ttf.Font = undefined;
    pub const position: SDL.Point = .{ .x = -2265, .y = 8900 };
    pub const frame = struct {
        pub var texture: SDL.Texture = undefined;
        pub const rect: SDL.Rectangle = .{ .x = -3000, .y = 0, .width = 2000, .height = 10000 };
    };
    pub const method = struct {
        pub const fg: SDL.Color = SDL.Color.red;
        //defined in stack init function. . .
        pub var bg: SDL.Texture = undefined;
        pub const size: SDL.Size = .{ .width = 850, .height = 425 };
    };
};
