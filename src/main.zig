const std = @import("std");
const TARGET_OS = @import("builtin").os.tag;
const sdl = @cImport({
    @cInclude("SDL2/SDL.h");
});
const zigimg = @import("zigimg");
const Font = @import("font/font.zig");
const FontAttributes = Font.FontAttributes;
const lhmem = @import("memory/memory.zig");
const Arena = lhmem.Arena;
const lhvk = @import("graphics/lhvk.zig");
const windowing = if (@import("builtin").os.tag == .windows) @import("graphics/win32.zig") else @import("graphics/wayland.zig");


const la = @import("lin_alg/la.zig");
const FONT_ROWS = 7;
const FONT_COLS = 18;
const FONT_WIDTH = 128;
const FONT_HEIGHT = 64;
const FONT_CHAR_WIDTH = FONT_WIDTH / FONT_COLS;
const FONT_CHAR_HEIGHT = FONT_HEIGHT / FONT_ROWS;

const print = std.debug.print;

const Application = struct {
    graphics_ctx: lhvk.LhvkGraphicsCtx,
};

const BufferPos2D = struct {
    x: i32,
    y: i32,

    pub fn init(x: i32, y: i32) BufferPos2D {
        return BufferPos2D{ .x = x, .y = y };
    }

    pub fn cmp(self: *const BufferPos2D, b: *const BufferPos2D) i32 {
        if (self.y == b.y) {
            return if (self.x >= b.x) 1 else -1;
        } else {
            return if (self.y >= b.y) 1 else -1;
        }
    }
};

const Buffer = struct {
    arena: Arena,
    cursor_pos: BufferPos2D,
    global_cursor_pos: usize,
    mark_pos: BufferPos2D,
    buffer: *std.ArrayList(u8),
    file_name: ?[]const u8,
    file: ?std.fs.File,

    pub fn open_or_create_file(buffer: *Buffer, path: []const u8) !void {
        buffer.file = std.fs.cwd().openFile(path, .{ .mode = .read_write, .lock = .none }) catch blk: {
            break :blk try std.fs.cwd().createFile(path, .{ .read = true });
        };
        if (buffer.file) |file| {
            buffer.file_name = path;
            buffer.cursor_pos = .{ .x = 0, .y = 0 };
            buffer.global_cursor_pos = 0;
            buffer.mark_pos = buffer.cursor_pos;
            var buffered = std.io.bufferedReader(file.reader());
            const metadata = try file.metadata();
            try buffer.buffer.resize(metadata.size());
            print("{}", .{metadata.size()});
            _ = try buffered.read(buffer.buffer.items);
        }
    }
    pub fn save_file(buf: *Buffer) !void {
        if (buf.file) |file| {
            file.close();
            buf.file = try std.fs.cwd().createFile(buf.file_name.?, .{ .truncate = true });
            try buf.file.?.writeAll(buf.buffer.items);
        }
    }
};

pub fn line_length(text: *const std.ArrayList(u8), line: usize) usize {
    var len: usize = 0;
    if (line == 0) {
        while (len < text.items.len and text.items[len] != '\n') {
            len += 1;
        }
    } else {
        var walker: usize = 0;
        var found_b_n: u32 = 0;
        while (true) {
            if (text.items[walker] == '\n') found_b_n += 1;
            walker += 1;
            if (found_b_n == line) break;
        }
        while (walker < text.items.len and text.items[walker] != '\n') {
            len += 1;
            walker += 1;
        }
    }
    return len;
}

pub fn render_char(renderer: *sdl.SDL_Renderer, font: *sdl.SDL_Texture, c: u8, pos: la.Vec2f, color: u32, scale: f32) void {
    if (c > 0) {
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
}

pub fn render_text(renderer: *sdl.SDL_Renderer, font: *sdl.SDL_Texture, text: []const u8, pos: la.Vec2f, color: u32, scale: f32) void {
    var pen = pos;
    for (text) |c| {
        if (c == '\n') {
            pen = la.vec2f(0, pen.y);
            pen = la.vec2f_add(pen, la.vec2f(0, FONT_CHAR_HEIGHT * scale));
        } else {
            render_char(renderer, font, c, pen, color, scale);
            pen = la.vec2f_add(pen, la.vec2f(FONT_CHAR_WIDTH * scale, 0));
        }
    }
}

pub fn render_cursor(renderer: *sdl.SDL_Renderer, buffer: Buffer, color: u32, scale: f32) void {
    const r: u8 = @intCast((color >> 16) & 0xff);
    const g: u8 = @intCast((color >>  8) & 0xff);
    const b: u8 = @intCast((color >>  0) & 0xff);
    const a: u8 = @intCast((color >> 24) & 0xff);
    _ = sdl.SDL_SetRenderDrawColor(renderer, r, g, b, a);

    const x: i32 = buffer.cursor_pos.x;
    const y: i32 = buffer.cursor_pos.y;

    const char_width: i32 = @intFromFloat(FONT_CHAR_WIDTH * scale);
    const char_height: i32 = @intFromFloat(FONT_CHAR_HEIGHT * scale);
    const fixed_g: i32 = 4;
    if (buffer.cursor_pos.cmp(&buffer.mark_pos) == 1) {
        const bottom_side: sdl.SDL_Rect = .{
            .x = x * char_width - @divTrunc(char_width, 2),
            .y = y * char_height + char_height - fixed_g,
            .w = @divTrunc(char_width, 2),
            .h = fixed_g,
        };
        const right_side: sdl.SDL_Rect = .{
            .x = x * char_width,
            .y = y * char_height,
            .w = fixed_g,
            .h = char_height,
        };
        _ = sdl.SDL_RenderFillRect(renderer, &bottom_side);
        _ = sdl.SDL_RenderFillRect(renderer, &right_side);
    } else {
        const left_side: sdl.SDL_Rect = .{
            .x = x * char_width,
            .y = y * char_height,
            .w = fixed_g,
            .h = char_height,
        };
        const top_side: sdl.SDL_Rect = .{
            .x = x * char_width,
            .y = y * char_height,
            .w = @divTrunc(char_width, 2),
            .h = fixed_g,
        };
        _ = sdl.SDL_RenderFillRect(renderer, &top_side);
        _ = sdl.SDL_RenderFillRect(renderer, &left_side);
    }
}

pub fn render_mark(renderer: *sdl.SDL_Renderer, buffer: Buffer, color: u32, scale: f32) void {
    const r: u8 = @intCast((color >> 16) & 0xff);
    const g: u8 = @intCast((color >> 8) & 0xff);
    const b: u8 = @intCast((color >> 0) & 0xff);
    const a: u8 = @intCast((color >> 24) & 0xff);
    _ = sdl.SDL_SetRenderDrawColor(renderer, r, g, b, a);

    const char_width: i32 = @intFromFloat(FONT_CHAR_WIDTH * scale);
    const char_height: i32 = @intFromFloat(FONT_CHAR_HEIGHT * scale);
    const fixed_g: i32 = 4;
    const x = buffer.mark_pos.x;
    const y = buffer.mark_pos.y;
    if (buffer.cursor_pos.cmp(&buffer.mark_pos) == -1) {
        const bottom_side: sdl.SDL_Rect = .{
            .x = x * char_width - @divTrunc(char_width, 2),
            .y = y * char_height + char_height - fixed_g,
            .w = @divTrunc(char_width, 2),
            .h = fixed_g,
        };
        const right_side: sdl.SDL_Rect = .{
            .x = x * char_width,
            .y = y * char_height,
            .w = fixed_g,
            .h = char_height,
        };
        _ = sdl.SDL_RenderFillRect(renderer, &bottom_side);
        _ = sdl.SDL_RenderFillRect(renderer, &right_side);
    } else {
        const left_side: sdl.SDL_Rect = .{
            .x = x * char_width,
            .y = y * char_height,
            .w = fixed_g,
            .h = char_height,
        };
        const top_side: sdl.SDL_Rect = .{
            .x = x * char_width,
            .y = y * char_height,
            .w = @divTrunc(char_width, 2),
            .h = fixed_g,
        };
        _ = sdl.SDL_RenderFillRect(renderer, &top_side);
        _ = sdl.SDL_RenderFillRect(renderer, &left_side);
    }
}

pub fn main() !void {
    _ = Font;
    _ = FontAttributes;


    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    const allocator = std.heap.page_allocator;
    defer arena.deinit();

    if (sdl.SDL_Init(sdl.SDL_INIT_VIDEO) < 0) {
        return error.MainSDLError;
    }

    _ = sdl;

    var window: *sdl.SDL_Window = undefined;
    var renderer: *sdl.SDL_Renderer = undefined;

    window = sdl.SDL_CreateWindow("my window", 100, 100, 640, 480, sdl.SDL_WINDOW_SHOWN | sdl.SDL_WINDOW_RESIZABLE).?;
    renderer = sdl.SDL_CreateRenderer(window, -1, sdl.SDL_RENDERER_ACCELERATED).?;


    var app: Application = undefined;
    app.graphics_ctx.window = windowing.create_window("algo");
    app.graphics_ctx.vk_app.arena = lhmem.make_arena((1<<10) * 24);
    app.graphics_ctx.vk_appdata.arena = lhmem.make_arena((1<<10) * 100);
    try lhvk.init_vulkan(&app.graphics_ctx);
    lhvk.prepare_frame(&app.graphics_ctx);
    lhvk.begin_command_buffer_rendering(&app.graphics_ctx);
    lhvk.end_command_buffer_rendering(&app.graphics_ctx);


    var arr = std.ArrayList(u8).init(allocator);
    var buffer: Buffer = Buffer{
        .arena = lhmem.make_arena(1 << 10),
        .cursor_pos = BufferPos2D.init(0, 0),
        .global_cursor_pos = 0,
        .mark_pos = BufferPos2D.init(2, 0),
        .buffer = &arr,
        .file_name = null,
        .file = null,
    };
    try buffer.open_or_create_file("main.c");
    var quit: bool = false;
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
                            if (buffer.cursor_pos.x > 0) {
                                buffer.cursor_pos.x -= 1;
                                buffer.global_cursor_pos -= 1;
                                _ = buffer.buffer.orderedRemove(buffer.global_cursor_pos);
                            }
                        },
                        sdl.SDLK_UP => {
                            if (buffer.cursor_pos.y > 0) {
                                buffer.cursor_pos.y -= 1;
                                buffer.global_cursor_pos -= @as(usize, @intCast(buffer.cursor_pos.x));
                                buffer.global_cursor_pos -= 1;
                                const len = line_length(buffer.buffer, @intCast(buffer.cursor_pos.y));
                                if (buffer.cursor_pos.x > len) {
                                    buffer.cursor_pos.x = @intCast(len);
                                } else {
                                    buffer.cursor_pos.x = buffer.cursor_pos.x;
                                }
                                buffer.global_cursor_pos -= len;
                                buffer.global_cursor_pos += @intCast(buffer.cursor_pos.x);
                            }
                        },
                        sdl.SDLK_DOWN => {
                            const len = line_length(buffer.buffer, @intCast(buffer.cursor_pos.y));
                            const first_in_next_line = ((buffer.global_cursor_pos - @as(usize, @intCast(buffer.cursor_pos.x))) + len + 1);
                            if (buffer.buffer.items.len > first_in_next_line) {
                                buffer.cursor_pos.y += 1;
                                buffer.global_cursor_pos -= @as(usize, @intCast(buffer.cursor_pos.x));
                                buffer.global_cursor_pos += len + 1;
                                const next_len = line_length(buffer.buffer, @intCast(buffer.cursor_pos.y));
                                if (buffer.cursor_pos.x > next_len) {
                                    buffer.cursor_pos.x = @intCast(next_len);
                                }
                                buffer.global_cursor_pos += @intCast(buffer.cursor_pos.x);
                            }
                        },
                        sdl.SDLK_LEFT => {
                            if (buffer.cursor_pos.x > 0) {
                                buffer.cursor_pos.x -= 1;
                                buffer.global_cursor_pos -= 1;
                            }
                        },
                        sdl.SDLK_RIGHT => {
                            if (buffer.global_cursor_pos < buffer.buffer.items.len and buffer.buffer.items[buffer.global_cursor_pos] != '\n') {
                                buffer.cursor_pos.x += 1;
                                buffer.global_cursor_pos += 1;
                            }
                        },
                        sdl.SDLK_RETURN => {
                            try buffer.buffer.insert(buffer.global_cursor_pos, '\n');
                            buffer.cursor_pos.x = 0;
                            buffer.cursor_pos.y = buffer.cursor_pos.y + 1;
                            buffer.global_cursor_pos += 1;
                        },
                        else => {},
                    }
                },
                sdl.SDL_TEXTINPUT => {
                    const char = event.text.text;
                    try buffer.buffer.insert(buffer.global_cursor_pos, char[0]);
                    buffer.cursor_pos.x += 1;
                    buffer.global_cursor_pos += 1;
                },
                else => {},
            }
        }
        _ = sdl.SDL_SetRenderDrawColor(renderer, 0x0C, 0x0C, 0x0C, 0);
        _ = sdl.SDL_RenderClear(renderer);

        render_cursor(renderer, buffer, 0x0000FF000, 5);
        render_mark(renderer, buffer, 0x00009900, 5);
        sdl.SDL_RenderPresent(renderer);
    }
    sdl.SDL_Quit();
    print("SE ACABO", .{});
    try buffer.save_file();
}
