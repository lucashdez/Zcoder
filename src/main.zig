const std = @import("std");
const sdl = @cImport({
    @cInclude("SDL2/SDL.h");
});

const FONT_WIDTH: c_int = 1;
const FONT_HEIGHT: c_int = 2;

pub fn create_surface_from_file(file_path: []const u8) !sdl.SDL_Surface {
    if (file_path) {
        std.io.GenericReader().readUntilDelimiterOrEof();
    
    }

    var rmask: u32 = 0;
    var gmask: u32 = 0;
    var bmask: u32 = 0;
    var amask: u32 = 0;
    if (sdl.SDL_BYTEORDER == sdl.SLD_BIG_ENDIAN) {
        rmask = 0x000000FF;
        gmask = 0x0000FF00;
        bmask = 0x00FF0000;
        amask = 0xFF000000;
    } else {
        rmask = 0xFF000000;
        gmask = 0x00FF0000;
        bmask = 0x0000FF00;
        amask = 0x000000FF;
    }

    //return SDL_CreateRGBSurfaceFrom(pixels: ?*anyopaque,
    //                         width: c_int, height: c_int, depth: c_int, pitch: c_int,
    //                         rmask, gmask, bmask, amask);
    return error.A;

}

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
    const texture: *sdl.SDL_Texture =
        sdl.SDL_CreateTexture(renderer, sdl.SDL_PIXELFORMAT_INDEX8, sdl.SDL_TEXTUREACCESS_STATIC, FONT_WIDTH, FONT_HEIGHT).?;

    _ = texture;
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
