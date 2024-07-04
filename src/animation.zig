const SDL = @import("sdl2");
const std = @import("std");
const Action = @import("action.zig");

pub const ZoomAnimation = struct {
    start_state: SDL.RectangleF,
    end_state: SDL.RectangleF,
    total_duration: i128,
    passed_duration: i128 = 0,
    done: bool = false,

    pub fn init(start: SDL.RectangleF, end: SDL.RectangleF, duration_nano: i128) ZoomAnimation {
        return ZoomAnimation{
            .start_state = start,
            .end_state = end,
            .total_duration = duration_nano,
        };
    }
    pub fn update(self: *ZoomAnimation, time_delta: i128) SDL.RectangleF {
        self.passed_duration += time_delta;
        if (self.done or self.passed_duration >= self.total_duration) {
            self.done = true;
            return self.end_state;
        }
        const fraction_passed: f128 = @as(f128, @floatFromInt(self.passed_duration)) / @as(f128, @floatFromInt(self.total_duration));
        return SDL.RectangleF{
            .x = @floatCast((self.end_state.x - self.start_state.x) * fraction_passed + self.start_state.x),
            .y = @floatCast((self.end_state.y - self.start_state.y) * fraction_passed + self.start_state.y),
            .width = @floatCast((self.end_state.width - self.start_state.width) * fraction_passed + self.start_state.width),
            .height = @floatCast((self.end_state.height - self.start_state.height) * fraction_passed + self.start_state.height),
        };
    }
};

pub const Animation = struct {
    zoom_animation: ZoomAnimation,
    action: Action.Action,
    pub fn run(self: Animation, time_delta: i128, data: *anyopaque) void {
        if (self.zoom_animation.done) {
            self.action.do(data);
        } else {
            self.zoom_animation.update(time_delta);
        }
    }
};
