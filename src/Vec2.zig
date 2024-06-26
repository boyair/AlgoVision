pub const Vec2 = struct {
    x: f32,
    y: f32,

    pub fn init(x: f32, y: f32) Vec2 {
        return Vec2{ .x = x, .y = y };
    }
    pub fn div(self: Vec2, divisor: Vec2) !Vec2 {
        if (divisor.x == 0 or divisor.y == 0) {
            return error.divError;
        }
        return Vec2{ .x = self.x / divisor.x, .y = self.y / divisor.y };
    }
    pub fn mul(self: Vec2, multiplier: Vec2) Vec2 {
        return Vec2{ .x = self.x * multiplier.x, .y = self.y * multiplier.y };
    }
};

const std = @import("std");
const testing = std.testing;
test "operations" {
    const v1: Vec2 = .{ .x = 34, .y = 10 };
    const v2: Vec2 = .{ .x = 3.4, .y = 100 };
    const v3: Vec2 = .{ .x = 10, .y = 0 };
    try testing.expectEqualDeep(v1.mul(v3), Vec2{ .x = 340, .y = 0 });
    try testing.expectEqualDeep(v1.div(v2), Vec2{ .x = 10, .y = 0.1 });
    try testing.expectEqualDeep(v2.div(v3), error.divError);
}
