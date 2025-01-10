const std = @import("std");
const sdl = @cImport({
    @cInclude("SDL2/SDL.h");
});
const zigimg = @import("zigimg");

const la = @import("lin_alg/la.zig");
const FONT_ROWS = 7;
const FONT_COLS = 18;
const FONT_WIDTH = 128;
const FONT_HEIGHT = 64;
const FONT_CHAR_WIDTH = FONT_WIDTH / FONT_COLS;
const FONT_CHAR_HEIGHT = FONT_HEIGHT / FONT_ROWS;

const print = std.debug.print;

const PixelMask = struct {
    red: u32,
    green: u32,
    blue: u32,
    alpha: u32,

    const Self = @This();
    /// construct a pixelmask given the colorstorage.
    /// *Attention*: right now only works for 24-bit RGB, BGR and 32-bit RGBA,BGRA
    pub fn fromPixelStorage(storage: zigimg.color.PixelStorage) !Self {
        switch (storage) {
            .bgra32 => return Self{
                .red = 0x00ff0000,
                .green = 0x0000ff00,
                .blue = 0x000000ff,
                .alpha = 0xff000000,
            },
            .rgba32 => return Self{
                .red = 0x000000ff,
                .green = 0x0000ff00,
                .blue = 0x00ff0000,
                .alpha = 0xff000000,
            },
            .bgr24 => return Self{
                .red = 0xff0000,
                .green = 0x00ff00,
                .blue = 0x0000ff,
                .alpha = 0,
            },
            .rgb24 => return Self{
                .red = 0x0000ff,
                .green = 0x00ff00,
                .blue = 0xff0000,
                .alpha = 0,
            },
            else => return error.InvalidColorStorage,
        }
    }
};

const PixelInfo = struct {
    /// bits per pixel
    bits: c_int,
    /// the pitch (see SDL docs, this is the width of the image times the size per pixel in byte)
    pitch: c_int,
    /// the pixelmask for the (A)RGB storage
    pixelmask: PixelMask,

    const Self = @This();

    pub fn from(image: zigimg.Image) !Self {
        const Sizes = struct { bits: c_int, pitch: c_int };
        const sizes: Sizes = switch (image.pixels) {
            .bgra32 => Sizes{ .bits = 32, .pitch = 4 * @as(c_int, @intCast(image.width)) },
            .rgba32 => Sizes{ .bits = 32, .pitch = 4 * @as(c_int, @intCast(image.width)) },
            .rgb24 => Sizes{ .bits = 24, .pitch = 3 * @as(c_int, @intCast(image.width)) },
            .bgr24 => Sizes{ .bits = 24, .pitch = 3 * @as(c_int, @intCast(image.width)) },
            else => return error.InvalidColorStorage,
        };
        return Self{ .bits = @as(c_int, @intCast(sizes.bits)), .pitch = @as(c_int, @intCast(sizes.pitch)), .pixelmask = try PixelMask.fromPixelStorage(image.pixels) };
    }
};

pub fn render_char(renderer: *sdl.SDL_Renderer, font: *sdl.SDL_Texture, c: u8, pos: la.Vec2f, color: u32, scale: f32) void {
    const index = c - 32;
    const col = index % FONT_COLS;
    const row = index / FONT_COLS;

    const src: sdl.SDL_Rect = .{
        .x = col * FONT_CHAR_WIDTH,
        .y = row * FONT_CHAR_HEIGHT,
        .w = FONT_CHAR_WIDTH,
        .h = FONT_CHAR_HEIGHT,
    };

    const dst: sdl.SDL_Rect = .{
        .x = @intFromFloat(pos.x),
        .y = @intFromFloat(pos.y),
        .w = @intFromFloat(FONT_CHAR_WIDTH * scale),
        .h = @intFromFloat(FONT_CHAR_HEIGHT * scale),
    };

    const r: u8 = @intCast((color >> 16) & 0xff);
    const g: u8 = @intCast((color >> 8) & 0xff);
    const b: u8 = @intCast((color >> 0) & 0xff);
    const a: u8 = @intCast((color >> 24) & 0xff);
    _ = sdl.SDL_SetTextureColorMod(font, r, g, b);
    _ = sdl.SDL_SetTextureAlphaMod(font, a);

    _ = sdl.SDL_RenderCopy(renderer, font, &src, &dst);
}

pub fn render_text(renderer: *sdl.SDL_Renderer, font: *sdl.SDL_Texture, text: []const u8, pos: la.Vec2f, color: u32, scale: f32) void {
    //const len = text.len;
    var pen = pos;
    for (text) |c| {
        render_char(renderer, font, c, pen, color, scale);
        pen = la.vec2f_add(pen, la.vec2f(FONT_CHAR_WIDTH * scale, 0));
    }
}

// TODO: Render cursor
pub fn render_cursor(renderer: *sdl.SDL_Renderer, pos: la.Vec2f, color: u32, scale: f32) void {


}
// TODO: Move cursor
// TODO: Buffer capacity
// TODO: Load/save buffers

pub fn create_surface_from_file(arena: *std.heap.ArenaAllocator, file_path: []const u8) !*sdl.SDL_Surface {
    const allocator = arena.allocator();
    if (!std.mem.eql(u8, file_path, "")) {
        var file = std.fs.cwd().openFile(file_path, .{}) catch {
            print("cannot read file\n", .{});
            return error.CannotOpenFile;
        };
        const img = try zigimg.Image.fromFile(allocator, &file);
        const pixel_info = try PixelInfo.from(img);

        const image_data: *anyopaque = blk: {
            switch (img.pixels) {
                .bgr24 => |bgr24| break :blk @as(*anyopaque, @ptrCast(bgr24.ptr)),
                .bgra32 => |bgra32| break :blk @as(*anyopaque, @ptrCast(bgra32.ptr)),
                .rgba32 => |rgba32| break :blk @as(*anyopaque, @ptrCast(rgba32.ptr)),
                .rgb24 => |rgb24| break :blk @as(*anyopaque, @ptrCast(rgb24.ptr)),
                else => return error.InvalidColorStorage,
            }
        };

        const surface = sdl.SDL_CreateRGBSurfaceFrom(image_data, @intCast(img.width), @intCast(img.height), pixel_info.bits, pixel_info.pitch, pixel_info.pixelmask.red, pixel_info.pixelmask.green, pixel_info.pixelmask.blue, pixel_info.pixelmask.alpha);
        if (surface == null) {
            const err = sdl.SDL_GetError();
            std.debug.print("ERROR: {s}\n", .{err});
        }
        return surface;
    } else {
        return error.NoFile;
    }
}

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    if (sdl.SDL_Init(sdl.SDL_INIT_VIDEO) < 0) {
        return error.MainSDLError;
    }

    _ = sdl;

    var window: *sdl.SDL_Window = undefined;
    var surface: *sdl.SDL_Surface = undefined;
    var renderer: *sdl.SDL_Renderer = undefined;

    window = sdl.SDL_CreateWindow("my window", 100, 100, 640, 480, sdl.SDL_WINDOW_SHOWN | sdl.SDL_WINDOW_RESIZABLE).?;
    renderer = sdl.SDL_CreateRenderer(window, -1, sdl.SDL_RENDERER_ACCELERATED).?;
    surface = try create_surface_from_file(&arena, "font_white.png");
    const font_texture: *sdl.SDL_Texture = sdl.SDL_CreateTextureFromSurface(renderer, surface).?;
    var quit: bool = false;
    var buffer: [15]u8 = undefined;
    var cursor: u64 = 0;
    while (!quit) {
        var event: sdl.SDL_Event = undefined;
        while (sdl.SDL_PollEvent(&event) > 0) {
            switch (event.type) {
                sdl.SDL_QUIT => {
                    quit = true;
                },
                sdl.SDL_KEYDOWN => {
                    switch (event.key.keysym.sym) {
                        sdl.SDLK_BACKSPACE => {
                            if (cursor > 0) {
                                cursor -= 1;
                                buffer[cursor] = ' ';
                            }
                        },
                        else => {},
                    }
                },
                sdl.SDL_TEXTINPUT => {
                    const char = event.text.text;
                    buffer[cursor] = char[0];
                    cursor += 1;
                    print("TextRecieved", .{});
                },
                else => {},
            }
        }
        _ = sdl.SDL_SetRenderDrawColor(renderer, 0, 0, 0, 0);
        _ = sdl.SDL_RenderClear(renderer);

        render_text(renderer, font_texture, &buffer, la.vec2f(0, 0), 0x23FF0000, 5);
        render_cursor(renderer, la.vec2f(cursor, 0), 0x0000FF000, 5);
        sdl.SDL_RenderPresent(renderer);
    }
    sdl.SDL_Quit();
}
