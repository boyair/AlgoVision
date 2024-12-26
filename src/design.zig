const SDL = @import("SDL");
const View = @import("view.zig").View;
pub var BG_color: SDL.Color = SDL.Color.rgb(90, 90, 90);
pub const fps = 240;
pub const frame_time_nano = 1_000_000_000 / fps;

pub const heap = struct {
    pub const num_title = struct {
        pub var font: SDL.ttf.Font = undefined;
        pub const color: SDL.Color = SDL.Color.blue;
        pub const size = block.size;
    };

    pub const title = struct {
        pub var texture: SDL.Texture = undefined; // initiallized in heap init function
        pub const color = SDL.Color.red;
        pub const rect: SDL.Rectangle = .{ .width = 500, .height = 200, .x = position.x, .y = position.y - 300 };
    };
    //defined in heap init function
    pub var font: SDL.ttf.Font = undefined;

    pub const block = struct {
        pub const size: SDL.Size = .{ .width = 88, .height = 88 };
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
    pub const position: SDL.Point = .{ .x = 0, .y = 0 };
};
pub const pointer = struct {
    pub var arrow: SDL.Texture = undefined;
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
    pub const CBfreecam = SDL.Rectangle{ .x = 25, .y = 210, .width = 45, .height = 45 };
    pub const pointers = element{
        .rect = .{ .x = 100, .y = 300, .width = 220, .height = 65 },
        .color = SDL.Color.white,
    };
    pub const rt_err = element{
        .rect = .{ .x = 0, .y = 800, .width = 220, .height = 65 },
        .color = SDL.Color.red,
    };
    pub const CBpointers = SDL.Rectangle{ .x = 25, .y = 310, .width = 45, .height = 45 };
    pub const exit_button = SDL.Rectangle{ .x = 400, .y = 0, .width = 45, .height = 45 };
};

pub const stack = struct {
    pub const title = struct {
        pub var texture: SDL.Texture = undefined; // initiallized in stack init function
        pub const color = SDL.Color.red;
        pub const rect: SDL.Rectangle = .{ .width = 500, .height = 200, .x = position.x, .y = position.y - 300 };
    };
    //defined in stack init function
    pub var font: SDL.ttf.Font = undefined;
    pub const position: SDL.Point = .{ .x = -1265, .y = -3000 };
    pub const method = struct {
        pub const fg: SDL.Color = SDL.Color.red;
        //defined in stack init function. . .
        pub var bg: SDL.Texture = undefined;
        pub const size: SDL.Size = .{ .width = 850, .height = 425 };
    };
    pub var mainMethod: SDL.Texture = undefined; // initiallized in stack init function
    pub const frame = struct {
        pub const color = SDL.Color.black;
        pub const thickness = 40;
    };
};
pub const action = struct {
    const sound = @import("sound.zig");
    const action_count = @import("std").meta.fields(@import("action.zig").actions).len;
    pub var action_sounds: [action_count]?sound.Wav = undefined;
    pub const action_sound_paths: [action_count][]const u8 = .{
        "/sounds/set_value_heap.wav",
        "/sounds/allocate.wav",
        "/sounds/free.wav",
        "/sounds/make_pointer.wav",
        "/sounds/remove_pointer.wav",
        "",
        "/sounds/call.wav",
        "/sounds/eval_function.wav",
        "",
        "/sounds/stack_pop.wav",
        "",
        "",
        "",
    };
};
