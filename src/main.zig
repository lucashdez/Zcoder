const std = @import("std");
const sdl = @cImport({
    @cInclude("SDL2/SDL.h");
});

const FONT_WIDTH: c_int = 1;
const FONT_HEIGHT: c_int = 1;
const FONT = [_]u8 {0xF0};

pub fn create_surface_from_file(file_path: []const u8) ! *sdl.SDL_Surface {
    //var gpa = std.heap.GeneralPurposeAllocator(std.heap.page_allocator);
    //const allocator = gpa.allocator();
    if (!std.mem.eql(u8, file_path, "")) {
        //const flags: std.fs.File.OpenFlags = .{.mode = .read_only, .lock = .none, .allow_ctty = false, .lock_nonblocking = false};
        //const file: std.fs.File = try std.fs.cwd()
        //    .openFile(file_path, flags);
        //const data = try file.reader().readAllAlloc(allocator, 1<<10);
        //std.debug.print("hello: {s}", .{data});

        var rmask: u32 = 0;
        var gmask: u32 = 0;
        var bmask: u32 = 0;
        var amask: u32 = 0;
        if (sdl.SDL_BYTEORDER == sdl.SDL_BIG_ENDIAN) {
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
        const surface = sdl.SDL_CreateRGBSurfaceFrom(@constCast(&FONT),
                                 1, 1, 8, FONT_WIDTH,
                                 rmask, gmask, bmask, amask);
        const err = sdl.SDL_GetError();
        std.debug.print("ERROR: {s}\n", .{err});
        return surface;
    } else {
        return error.NoFile;
    }
}

pub fn main() !void {
    if (sdl.SDL_Init(sdl.SDL_INIT_VIDEO) < 0) {
        return error.MainSDLError;
    }

    _ = sdl;

    var window: *sdl.SDL_Window = undefined;
    var surface: *sdl.SDL_Surface = undefined;
    var renderer: *sdl.SDL_Renderer = undefined;

    window = sdl.SDL_CreateWindow("my window", 100, 100, 640, 480, sdl.SDL_WINDOW_SHOWN | sdl.SDL_WINDOW_RESIZABLE).?;
    renderer = sdl.SDL_CreateRenderer(window, -1, sdl.SDL_RENDERER_ACCELERATED).?;
    surface = try create_surface_from_file("font.jpg");
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
