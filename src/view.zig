const std = @import("std");
const SDL = @import("sdl2");
const Vec2 = @import("Vec2.zig").Vec2;
const conertVecSize = @import("SDLex.zig").conertVecSize;

const viewError = error{
    outOfView,
};

pub const View = struct {
    port: SDL.RectangleF,
    window_size: SDL.Size,

    pub fn init(window: *SDL.Window) View {
        const window_size: SDL.Size = window.getSize();
        return .{
            .port = .{ .x = 0, .y = 0, .width = @floatFromInt(window_size.width), .height = @floatFromInt(window_size.height) },
            .window_size = window.getSize(),
        };
    }

    pub fn convert(self: View, original: SDL.RectangleF) viewError!SDL.RectangleF {
        if (!original.hasIntersection(self.port)) {
            return viewError.outOfView;
        }
        //turn values to floats to allow fractional offset and scaling calculations.
        const win_sizeF = conertVecSize(self.window_size);
        var result = original;
        result.x -= self.port.x;
        result.y -= self.port.y;
        result.x *= win_sizeF.x / self.port.width;
        result.y *= win_sizeF.y / self.port.height;
        result.width *= win_sizeF.x / self.port.width;
        result.height *= win_sizeF.y / self.port.height;
        return result;
    }
    pub fn scale_vec_win_to_port(self: View, original: Vec2) Vec2 {
        const win_sizeF = conertVecSize(self.window_size);
        return Vec2{ .x = original.x * win_sizeF.x / self.port.width, .y = original.y * win_sizeF.y / self.port.height };
    }
    pub fn scale_vec_port_to_win(self: View, original: Vec2) Vec2 {
        const win_sizeF = conertVecSize(self.window_size);
        return Vec2{ .x = original.x * self.port.width / win_sizeF.x, .y = original.y * self.port.height / win_sizeF.y };
    }

    //resize and move the view-port to create a zoom effect.
    pub fn zoom(self: *View, scale: f32, point: ?SDL.Point) void {
        if (scale == 0)
            return;

        //turn values to floats to allow fractional offset and scaling calculations.
        const win_sizeF = .{
            .width = @as(f32, @floatFromInt(self.window_size.width)),
            .height = @as(f32, @floatFromInt(self.window_size.height)),
        };
        const save_rect: SDL.RectangleF = self.port;
        self.port.width /= scale;
        self.port.height /= scale;
        if (point) |p| {
            self.port.x += (save_rect.width - self.port.width) * @as(f32, @floatFromInt(p.x)) / win_sizeF.width;
            self.port.y += (save_rect.height - self.port.height) * @as(f32, @floatFromInt(p.y)) / win_sizeF.height;
        } else {
            self.port.x += (save_rect.width - self.port.width) / 2;
            self.port.y += (save_rect.height - self.port.height) / 2;
        }
    }
};
