const std = @import("std");
const sdl = @cImport({
    @cInclude("SDL2/SDL.h");
});

pub fn main() !void {
    if (sdl.SDL_Init(sdl.SDL_INIT_VIDEO) < 0) {
        return error.MainSDLError;
    }

    _ = sdl;

    var window: *sdl.SDL_Window = undefined;
    //var surface: *sdl.SDL_Surface = undefined;
    var renderer: *sdl.SDL_Renderer = undefined;

    window = sdl.SDL_CreateWindow("my window", 100, 100, 640, 480, sdl.SDL_WINDOW_SHOWN | sdl.SDL_WINDOW_RESIZABLE).?;
    renderer = sdl.SDL_CreateRenderer(window, -1, sdl.SDL_RENDERER_ACCELERATED).?;
    //surface = sdl.SDL_GetWindowSurface(window);
    var quit: bool = false;
    while (!quit) {
        var event: sdl.SDL_Event = undefined;
        while (sdl.SDL_PollEvent(&event) > 0) {
            switch (event.type) {
                sdl.SDL_QUIT => {
                    quit = true;
                },
                else => {},
            }
        }
        _ = sdl.SDL_SetRenderDrawColor(renderer, 255, 0, 0, 0);
        _ = sdl.SDL_RenderClear(renderer);
        sdl.SDL_RenderPresent(renderer);
    }
    sdl.SDL_Quit();
}
