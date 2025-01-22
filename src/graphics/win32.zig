const sdl = @cImport(@cInclude("SDL2/SDL.h"));

pub const Window = struct {
    handle: *sdl.SDL_Window,
};