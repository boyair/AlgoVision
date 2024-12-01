const std = @import("std");
const app = @import("../app.zig");
const SDL = @import("SDL");
const Internals = @import("internal.zig");
const View = @import("../view.zig").View;
const Operation = @import("../operation.zig");
const SDLex = @import("../SDLex.zig");
const design = @import("../design.zig").stack;
const Vec2 = @import("../Vec2.zig").Vec2;
const ZoomAnimation = @import("../animation.zig").ZoomAnimation;

var stack_len_runtime: isize = 0;

fn topMethodView(stack_len: isize) SDL.RectangleF {
    const view_size: f32 = @as(f32, @floatFromInt(@max(design.method.size.width, design.method.size.height))) * 2.0;
    const methodRect = SDL.Rectangle{
        .x = design.position.x,
        .y = design.position.y - @as(c_int, @intCast(design.method.size.height * stack_len)),
        .width = design.method.size.width,
        .height = design.method.size.height,
    };
    return SDLex.alignedRect(SDLex.convertSDLRect(methodRect), .{ .x = 0.5, .y = 0.5 }, Vec2.init(view_size, view_size));
}

pub fn call(comptime function: anytype, args: anytype) i64 {
    if (app.operation_manager.blocked_by_error) return 0;
    if (stack_len_runtime >= Internals.height_limit) {
        app.operation_manager.pushError(.{ .stack_overflow = {} });
        return 0;
    }
    //make animation
    const call_animation: ZoomAnimation = ZoomAnimation.init(&app.cam_view, null, topMethodView(stack_len_runtime), 500_000_000);
    //copy args to a list
    const method = Internals.MethodData{ .signiture = Internals.fmtz(args, app.Allocator.allocator()), .texture = null };
    //push call operation
    const call_operation: Operation.Operation = .{
        .action = .{ .call = method },
        .animation = call_animation,
        .pause_time_nano = 400_000_000,
    };
    app.operation_manager.push(app.Allocator.allocator(), call_operation);
    //NOTE:
    //important to call only after pushing call
    //operation in case function has a call inside
    //if called before the call stack will be flipped
    stack_len_runtime += 1;
    const eval = function(args);
    stack_len_runtime -= 1;

    const eval_animation: ZoomAnimation = ZoomAnimation.init(&app.cam_view, null, topMethodView(stack_len_runtime), 500_000_000);
    const eval_operation: Operation.Operation = .{ .action = .{ .eval_function = eval }, .animation = eval_animation, .pause_time_nano = 1_000_000_000 };
    app.operation_manager.push(app.Allocator.allocator(), eval_operation);

    const pop_animation: ZoomAnimation = ZoomAnimation.init(&app.cam_view, null, topMethodView(stack_len_runtime), 500_000_000);
    //non_animation.done = true;
    const pop: Operation.Operation = .{ .action = .{ .stack_pop = {} }, .animation = pop_animation, .pause_time_nano = 500_000_000 };
    app.operation_manager.push(app.Allocator.allocator(), pop);

    return eval;
}
