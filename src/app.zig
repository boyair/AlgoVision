const Vec2 = @import("Vec2.zig").Vec2;
const std = @import("std");
const SDL = @import("sdl2");
const SDLex = @import("SDLex.zig");
const View = @import("view.zig").View;
pub const heap = @import("heap/interface.zig");
const heap_internal = @import("heap/internal.zig");
pub const stack = @import("stack/interface.zig");
pub const stack_internal = @import("stack/internal.zig");
const Design = @import("design.zig");
const Operation = @import("operation.zig");
const Animation = @import("animation.zig");
const Pointer = @import("pointer.zig");
const UI = @import("UI.zig");
var gpa = std.heap.GeneralPurposeAllocator(.{}){};
//arena allocator for all the internal allocation of the application
pub var Allocator = std.heap.ArenaAllocator.init(gpa.allocator());
pub var exe_path: []u8 = undefined;

const fps = 240;
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
var running: bool = true;
const tick_rate = 1000; // logic updates per seconds
const tick_time = 1_000_000_000 / tick_rate; // time for logic update in ns
var loading_screen_texture: SDL.Texture = undefined;
var playback_speed: f128 = 1.0;
pub var freecam = false;
var current_action: Operation.Action.actions = .call;

//---------------------------------------------------
//---------------------------------------------------
//------------------INITIALIZATION-------------------
//---------------------------------------------------
//---------------------------------------------------
pub fn init() !void {
    if (initiallized) {
        std.debug.print("tried to initiallize app more than once!\nAborting initialization", .{});
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

    //init pointer
    try Pointer.init();
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

//---------------------------------------------------
//---------------------------------------------------
//----------------------RUNNING----------------------
//---------------------------------------------------
//---------------------------------------------------

pub fn start() !void {
    defer deinit();
    const logic_thread = try std.Thread.spawn(.{}, runLogic, .{});
    defer logic_thread.join();
    repeatTimed(renderFrame, frame_time_nano);
}

const example: Vec2 = .{
    .x = 9,
    .y = 7,
};
const element_params = .{
    &playback_speed,
    &current_action,
    &UI.VOID,
    &freecam,
    &running,
    &UI.FALSE,
    &UI.TRUE,
};
fn renderFrame(iteration_time: i128) void {
    _ = iteration_time;
    stack_internal.reciveTextureUpdateSignal();
    stack_internal.clearGarbageTextures();
    renderer.clear() catch unreachable;
    heap_internal.draw(renderer, cam_view);
    stack_internal.draw(renderer, cam_view);
    Pointer.draw(cam_view, renderer);
    UI.drawBG() catch unreachable;
    inline for (UI.elements, 0..) |element, idx| {
        element.draw(element_params[idx].*);
    }
    renderer.present();
}

fn tickUpdate(last_iteration_time: i128) void {
    operation_manager.update(@intFromFloat(@as(f128, @floatFromInt(last_iteration_time)) * playback_speed), !freecam);
    if (operation_manager.current_operation) |operation| {
        current_action = operation.data.action;
    }
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
        inline for (UI.elements, 0..) |element, idx| {
            element.handleEvent(&ev, mouse_pos, element_params[idx]);
        }
    }
}

//---------------------------------------------------
//---------------------------------------------------
//----------------------HELPERS----------------------
//---------------------------------------------------
//---------------------------------------------------

fn repeatTimed(func: fn (i128) void, iterationTime: i128) void {
    var last_iteration_time: i128 = 0;
    while (running) {
        const start_time = std.time.nanoTimestamp();
        func(last_iteration_time);
        const sleep_time: i128 = iterationTime - (std.time.nanoTimestamp() - start_time);
        if (sleep_time > 0) {
            std.time.sleep(@intCast(sleep_time));
        }
        const end_time = std.time.nanoTimestamp();
        last_iteration_time = end_time - start_time;
    }
}
fn runLogic() void {
    repeatTimed(tickUpdate, tick_time);
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
