const SDL = @import("SDL");
const std = @import("std");
const View = @import("view.zig").View;

pub const ZoomAnimation = struct {
    start_state: SDL.RectangleF,
    end_state: SDL.RectangleF,
    total_duration: i128,
    passed_duration: i128 = 0,
    done: bool = false,
    view: *View,

    pub fn init(view: *View, start: ?SDL.RectangleF, end: SDL.RectangleF, duration_nano: i128) ZoomAnimation {
        return ZoomAnimation{
            .start_state = start orelse view.cam,
            .end_state = end,
            .total_duration = duration_nano,
            .view = view,
        };
    }
    pub fn update(self: *ZoomAnimation, time_delta: i128) void {
        self.passed_duration += time_delta;
        if (self.done or self.passed_duration >= self.total_duration) {
            self.done = true;
            self.view.cam = self.end_state;
            return;
        }
        const fraction_passed: f128 = @as(f128, @floatFromInt(self.passed_duration)) / @as(f128, @floatFromInt(self.total_duration));
        self.view.cam = SDL.RectangleF{
            .x = @floatCast((self.end_state.x - self.start_state.x) * fraction_passed + self.start_state.x),
            .y = @floatCast((self.end_state.y - self.start_state.y) * fraction_passed + self.start_state.y),
            .width = @floatCast((self.end_state.width - self.start_state.width) * fraction_passed + self.start_state.width),
            .height = @floatCast((self.end_state.height - self.start_state.height) * fraction_passed + self.start_state.height),
        };
    }
    pub fn isDone(self: *ZoomAnimation) bool {
        self.done = self.done or self.passed_duration >= self.total_duration;
        return self.done;
    }
};

pub fn nonAnimation() ZoomAnimation {
    var view = View.init(.{ .x = 0, .y = 0, .width = 0, .height = 0 });
    return ZoomAnimation.init(&view, .{ .x = 0, .y = 0, .width = 0, .height = 0 }, .{ .x = 0, .y = 0, .width = 0, .height = 0 }, 0);
}
