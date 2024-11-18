const std = @import("std");
const Vec2 = @import("Vec2.zig").Vec2;

pub const Line = struct {
    start: Vec2,
    end: Vec2,
    const Self = @This();
    pub fn Length(self: Self) f32 {
        const xdiff = std.math.pow(f32, self.end.x - self.start.x, 2);
        const ydiff = std.math.pow(f32, self.end.y - self.start.y, 2);
        return std.math.sqrt(xdiff + ydiff);
    }
    pub fn diffx(self: Self) f32 {
        return self.end.x - self.start.x;
    }
    pub fn diffy(self: Self) f32 {
        return self.end.y - self.start.y;
    }
};
