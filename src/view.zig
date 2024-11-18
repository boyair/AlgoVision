const std = @import("std");
const SDL = @import("SDL");
const SDLex = @import("SDLex.zig");
const Vec2 = @import("Vec2.zig").Vec2;
const Line = @import("line.zig").Line;
const conertVecSize = @import("SDLex.zig").conertVecSize;

const viewError = error{
    outOfView,
};

pub const View = struct {
    cam: SDL.RectangleF, // camera
    port: SDL.Rectangle, // window part being drawn on
    border: ?SDL.RectangleF = null, // view port limited to stay inside border
    max_size: ?Vec2 = null,
    min_size: ?Vec2 = null,

    pub fn init(port: SDL.Rectangle) View {
        return .{
            .cam = SDLex.convertSDLRect(port),
            .port = port,
        };
    }

    pub fn convert(self: View, original: SDL.RectangleF) viewError!SDL.RectangleF {
        if (!original.hasIntersection(self.cam)) {
            return viewError.outOfView;
        }
        //turn values to floats to allow fractional offset and scaling calculations.
        const portF = SDLex.convertSDLRect(self.port);
        var result = original;
        result.x -= self.cam.x;
        result.y -= self.cam.y;
        result.x += portF.x;
        result.y += portF.y;
        result.x *= portF.width / self.cam.width;
        result.y *= portF.height / self.cam.height;
        result.width *= portF.width / self.cam.width;
        result.height *= portF.height / self.cam.height;
        return result;
    }
    pub fn scale_vec_port_to_cam(self: View, original: Vec2) Vec2 {
        const portF = SDLex.convertSDLRect(self.port);
        return Vec2{ .x = original.x * portF.width / self.cam.width, .y = original.y * portF.height / self.cam.height };
    }
    pub fn convertVec(self: View, original: Vec2) Vec2 {
        const portF = SDLex.convertSDLRect(self.port);
        return Vec2{ .x = (original.x - self.cam.x) * portF.width / self.cam.width, .y = (original.y - self.cam.y) * portF.height / self.cam.height };
    }

    pub fn scale_vec_cam_to_port(self: View, original: Vec2) Vec2 {
        const portF = SDLex.convertSDLRect(self.port);
        return Vec2{ .x = original.x * self.cam.width / portF.width, .y = original.y * self.cam.height / portF.height };
    }
    pub fn keepInLimits(self: *View) bool {
        const original_port = self.cam;
        if (self.min_size) |min| {
            self.cam.width = @max(self.cam.width, min.x);
            self.cam.height = @max(self.cam.height, min.y);
        }
        if (self.max_size) |max| {
            self.cam.width = @min(self.cam.width, max.x);
            self.cam.height = @min(self.cam.height, max.y);
        }
        if (self.border) |border| {
            self.cam.x = @max(border.x, self.cam.x);
            self.cam.y = @max(border.y, self.cam.y);
            self.cam.x = @min(border.x + border.width - self.cam.width, self.cam.x);
            self.cam.y = @min(border.y + border.height - self.cam.height, self.cam.y);
        }
        return !SDLex.compareRect(original_port, self.cam);
    }
    pub fn offLimits(self: View, future_port: SDL.RectangleF) bool {
        if (self.min_size) |min| {
            if (future_port.width < min.x) return true;
            if (future_port.height < min.y) return true;
        }
        if (self.max_size) |max| {
            if (future_port.width > max.x) return true;
            if (future_port.height > max.y) return true;
        }
        if (self.border) |border| {
            if (future_port.x < border.x) return true;
            if (future_port.y < border.y) return true;
            if (future_port.x > border.x + border.width - future_port.width) return true;
            if (future_port.y > border.y + border.height - future_port.height) return true;
        }
        return false;
    }

    //resize and move the view-port to create a zoom effect.
    pub fn zoom(self: *View, scale: f32, point: ?SDL.Point) void {
        if (scale == 0)
            return;

        //turn values to floats to allow fractional offset and scaling calculations.
        const portF = SDLex.convertSDLRect(self.port);
        const save_rect: SDL.RectangleF = self.cam;
        self.cam.width /= scale;
        self.cam.height /= scale;
        if (point) |p| {
            self.cam.x += (save_rect.width - self.cam.width) * @as(f32, @floatFromInt(p.x)) / portF.width;
            self.cam.y += (save_rect.height - self.cam.height) * @as(f32, @floatFromInt(p.y)) / portF.height;
        } else {
            self.cam.x += (save_rect.width - self.cam.width) / 2;
            self.cam.y += (save_rect.height - self.cam.height) / 2;
        }
        _ = keepInLimits(self);
    }
    pub fn getZoomed(self: View, scale: f32, point: ?SDL.Point) SDL.RectangleF {
        if (scale == 0) {
            return self.cam;
        }
        //turn values to floats to allow fractional offset and scaling calculations.
        const portF = SDLex.convertSDLRect(self.port);
        const save_rect: SDL.RectangleF = self.cam;
        var result = self.cam;
        result.width /= scale;
        result.height /= scale;
        if (point) |p| {
            result.x += (save_rect.width - result.width) * @as(f32, @floatFromInt(p.x)) / portF.width;
            result.y += (save_rect.height - result.height) * @as(f32, @floatFromInt(p.y)) / portF.height;
        } else {
            result.x += (save_rect.width - result.width) / 2;
            result.y += (save_rect.height - result.height) / 2;
        }
        return result;
    }

    //rendering functions
    pub fn draw(self: View, rect: SDL.RectangleF, texture: SDL.Texture, renderer: SDL.Renderer) void {
        const transformed = self.convert(rect) catch null;

        if (transformed) |in_view| {
            renderer.copy(texture, SDLex.convertSDLRect(in_view), null) catch unreachable;
        }
    }

    pub fn drawEx(self: View, rect: SDL.RectangleF, texture: SDL.Texture, renderer: SDL.Renderer, angle: f64, center: ?Vec2, flip: SDL.RendererFlip) void {
        const transformed = self.convert(rect) catch null;

        if (transformed) |in_view| {
            const center_point: ?SDL.Point = if (center) |cntr| SDL.Point{
                .x = @intFromFloat(in_view.width * cntr.x),
                .y = @intFromFloat(in_view.height * cntr.y),
            } else null;
            renderer.copyEx(texture, SDLex.convertSDLRect(in_view), null, angle, center_point, flip) catch unreachable;
        }
    }

    pub fn drawLine(self: View, line: Line, color: SDL.Color, renderer: SDL.Renderer) void {
        const transformed = blk: {
            const start = self.convertVec(line.start);
            const end = self.convertVec(line.end);
            break :blk Line{ .start = start, .end = end };
        };
        const last_color = renderer.getColor() catch SDL.Color.rgb(0, 0, 0);
        renderer.setColor(color) catch unreachable;
        renderer.drawLineF(transformed.start.x, transformed.start.y, transformed.end.x, transformed.end.y) catch unreachable;
        renderer.setColor(last_color) catch unreachable;
    }
    pub fn fillRect(self: View, rect: SDL.RectangleF, renderer: SDL.Renderer) void {
        const transformed = self.convert(rect) catch null;
        if (transformed) |in_view| {
            renderer.fillRect(SDLex.convertSDLRect(in_view)) catch unreachable;
        }
    }
};
