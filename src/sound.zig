const mixer = @cImport(@cInclude("SDL2/SDL_mixer.h"));
const SDL = @import("SDL");

pub fn init() !void {
    if (mixer.Mix_OpenAudio(48000, mixer.MIX_DEFAULT_FORMAT, 4, 1024) != 0)
        return SDL.makeError();
}

pub const Wav = struct {
    chunk: [*c]mixer.Mix_Chunk,
    channel: ?c_int = null,
    const Self = @This();
    pub fn init(path: [*c]const u8) !Self {
        return .{ .chunk = if (mixer.Mix_LoadWAV(path)) |chnk| chnk else return SDL.makeError() };
    }
    pub fn play(self: *Self, volume: c_int, loops: c_int) !void {
        self.channel = mixer.Mix_PlayChannel(-1, self.chunk, loops);
        if (self.channel.? == -1) {
            self.channel = null;
            return SDL.makeError();
        }
        _ = mixer.Mix_Volume(self.channel.?, volume);
    }
};
