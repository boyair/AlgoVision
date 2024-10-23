const std = @import("std");
const SDL = @import("sdl2");
const SDLex = @import("SDLex.zig");
const Vec2 = @import("Vec2.zig").Vec2;
const View = @import("view.zig").View;
pub const heap = @import("heap/interface.zig");
const heap_internal = @import("heap/internal.zig");
pub const stack = @import("stack/interface.zig");
pub const stack_internal = @import("stack/internal.zig");
const Design = @import("design.zig");
const Operation = @import("operation.zig");
const Animation = @import("animation.zig");
const UI = @import("UI.zig");
var gpa = std.heap.GeneralPurposeAllocator(.{}){};
//arena allocator for all the internal allocation of the application
pub var Allocator = std.heap.ArenaAllocator.init(gpa.allocator());
pub var exe_path: []u8 = undefined;

const fps = 144;
const frame_time_nano = 1_000_000_000 / fps;

const State = enum {
    heap,
    stack,
};

pub var operation_manager: Operation.Manager = undefined;
pub var window: SDL.Window = undefined;
pub var renderer: SDL.Renderer = undefined;
pub var cam_view: View = undefined;
var initiallized = false;
var state: State = State.heap;
var running_time: i128 = 0;
var running: bool = true;
const tick_rate = 200; // logic updates per seconds
const tick_time = 1_000_000_000 / tick_rate; // time for logic update in ns
var loading_screen_texture: SDL.Texture = undefined;

var playback_speed: f128 = 1.0;
pub var freecam = false;

pub fn init() !void {
    if (initiallized) {
        std.debug.print("tried to initiallize app more than once!", .{});
        return;
    }

    //  init basics
    try SDLex.fullyInitSDL();
    const display_info = SDL.DisplayMode.getDesktopInfo(0) catch unreachable;

    window = try SDL.createWindow("Application", .{ .centered = {} }, .{ .centered = {} }, @intCast(display_info.w), @intCast(display_info.h), .{ .vis = .shown, .resizable = false, .borderless = true, .mouse_capture = true });
    renderer = try SDL.createRenderer(window, null, .{ .accelerated = true });
    try renderer.setColor(Design.BG_color);
    cam_view = View.init(.{
        .x = 0,
        .y = 0,
        .width = @intFromFloat(@as(f64, @floatFromInt(display_info.w)) * (1.0 - Design.UI.width_portion)),
        .height = display_info.h,
    });
    Design.UI.view = View.init(.{ .x = cam_view.port.width, .y = 0, .width = display_info.w - cam_view.port.width, .height = display_info.h });
    Design.UI.view.cam.x = 0; // not require an offset when drawing ui.
    operation_manager = Operation.Manager.init();

    exe_path = try std.fs.selfExeDirPathAlloc(gpa.allocator());

    //init UI
    try UI.init(exe_path, "/3270.ttf", renderer);
    //loading screen

    loading_screen_texture = SDLex.textureFromText("Loading...", Design.UI.font, SDL.Color.rgb(150, 150, 150), renderer);
    try renderer.copy(loading_screen_texture, .{ .x = 0, .y = 200, .width = 1000, .height = 600 }, null);
    renderer.present();

    //init heap
    heap_internal.init(renderer, Allocator.allocator());

    //init stack
    try stack_internal.init();
    initiallized = true;
}

fn deinit() void {
    renderer.destroy();
    window.destroy();
    operation_manager.deinit(Allocator.allocator());
    UI.deinit();
    loading_screen_texture.destroy();
    heap_internal.deinit();
    Allocator.deinit();

    SDLex.fullyQuitSDL();
}

inline fn drawFrame() !void {
    try renderer.clear();
    heap_internal.draw(renderer, cam_view);
    stack_internal.draw(renderer, cam_view);

    try UI.drawBG();
    UI.speed_element.draw(playback_speed);
    UI.freecam_element.draw({});
    UI.freecam_checkbox.draw(freecam);
    UI.action_back.draw(false);
    UI.action_forward.draw(true);
    if (operation_manager.current_operation) |operation| {
        UI.action_element.draw(operation.data.action);
    }

    renderer.present();
}

fn tickUpdate(last_iteration_time: i128) !void {
    operation_manager.update(last_iteration_time, !freecam);
    const mouse_state = SDL.getMouseState();
    const mouse_pos: SDL.Point = .{ .x = mouse_state.x, .y = mouse_state.y };
    while (SDL.pollEvent()) |ev| {
        switch (ev) {
            .key_down => {
                if (ev.key_down.scancode == .left)
                    operation_manager.undoLast();
                if (ev.key_down.scancode == .right)
                    operation_manager.fastForward();
                if (ev.key_down.scancode == .escape)
                    running = false;
                if (ev.key_down.scancode == .space) {
                    playback_speed = if (playback_speed == 0) 1 else 0;
                }
            },
            .mouse_button_down => {
                if (ev.mouse_button_down.button == .left) {}
            },
            .mouse_wheel => {
                if (SDL.c.SDL_PointInRect(@ptrCast(&mouse_pos), @ptrCast(&cam_view.port)) == SDL.c.SDL_TRUE) {
                    if (freecam) {
                        const delta: f32 = @floatFromInt(ev.mouse_wheel.delta_y);
                        const zoomed_port = cam_view.getZoomed(1.0 + delta / 8.0, mouse_pos);
                        cam_view.cam = if (!cam_view.offLimits(zoomed_port)) zoomed_port else cam_view.cam;
                    }
                }
            },

            .mouse_motion => {
                const mouse_motion = cam_view.scale_vec_cam_to_port(SDLex.conertVecPoint(SDL.Point{ .x = ev.mouse_motion.delta_x, .y = ev.mouse_motion.delta_y }));
                if (freecam and
                    SDL.c.SDL_PointInRect(@ptrCast(&mouse_pos), @ptrCast(&cam_view.port)) == SDL.c.SDL_TRUE and
                    ev.mouse_motion.button_state.getPressed(.right))
                {
                    cam_view.cam.x -= mouse_motion.x;
                    cam_view.cam.y -= mouse_motion.y;
                }
            },

            .quit => {
                running = false;
            },
            else => {},
        }
        UI.speed_element.handleEvent(&ev, mouse_pos, &playback_speed);
        //UI.freecam_element.handleEvent(&ev, mouse_pos, &freecam);
        UI.freecam_checkbox.handleEvent(&ev, mouse_pos, &freecam);
        //simple var booleans i can pass as a parameter to the action arrows
        var always_false = false;
        var always_true = true;
        UI.action_back.handleEvent(&ev, mouse_pos, &always_false);
        UI.action_forward.handleEvent(&ev, mouse_pos, &always_true);
    }
}
fn runLogic() void {
    var last_iteration_time: i128 = 0;
    while (running) {
        const start_time = std.time.nanoTimestamp();
        last_iteration_time = @intFromFloat(@as(f128, @floatFromInt(last_iteration_time)) * playback_speed);
        try tickUpdate(last_iteration_time);

        const sleep_time: i128 = frame_time_nano - (std.time.nanoTimestamp() - start_time);
        if (sleep_time > 0) {
            std.time.sleep(@intCast(sleep_time));
        }
        const end_time = std.time.nanoTimestamp();
        std.time.sleep(@intCast(tick_time - (start_time - end_time)));
        last_iteration_time = end_time - start_time;
        running_time += last_iteration_time;
    }
}

pub fn start() !void {
    const logic_thread = try std.Thread.spawn(.{}, runLogic, .{});
    defer logic_thread.join();
    while (running) {
        const start_time = std.time.nanoTimestamp();
        try drawFrame();
        const sleep_time: i128 = frame_time_nano - (std.time.nanoTimestamp() - start_time);
        if (sleep_time > 0) {
            std.time.sleep(@intCast(sleep_time));
        }
        const end_time = std.time.nanoTimestamp();
        std.time.sleep(@intCast(Design.frame_time - (start_time - end_time)));
    }
    deinit();
}

//---------------------------------------------------
//---------------------------------------------------
//-----------------APP INTERFACE---------------------
//---------------------------------------------------
//---------------------------------------------------
pub fn log(comptime str: []const u8, args: anytype) void {
    const string = std.fmt.allocPrint(Allocator.allocator(), str, args) catch unreachable;
    var non_animation: Animation.ZoomAnimation = Animation.ZoomAnimation.init(&cam_view, null, .{ .x = 0, .y = 0, .width = 0, .height = 0 }, 0);
    non_animation.done = true;
    operation_manager.push(Allocator.allocator(), .{ .action = .{ .print = string }, .animation = non_animation, .pause_time_nano = 0 });
}
