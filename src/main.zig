const __DEBUG__: bool = true;
const std = @import("std");
const TARGET_OS = @import("builtin").os.tag;
const zigimg = @import("zigimg");
const Font = @import("font/font.zig");
const FontAttributes = Font.FontAttributes;
const lhmem = @import("memory/memory.zig");
const Arena = lhmem.Arena;
const lhvk = @import("graphics/lhvk.zig");
const windowing = if (@import("builtin").os.tag == .windows) @import("graphics/win32.zig") else @import("graphics/wayland.zig");
const e = @import("graphics/windowing/events.zig");
const la = @import("lin_alg/la.zig");
const print = std.debug.print;
const draw = @import("graphics/drawing/primitives.zig");
const v = @import("graphics/drawing/vertex.zig");
const VertexList = v.VertexList;


extern fn putenv(string: [*:0]const u8) c_int;

const Application = struct {
    graphics_ctx: lhvk.LhvkGraphicsCtx,
};

const Buffer = struct {
    arena: Arena,
    cursor_pos: usize,
    mark_pos: usize,
    buffer: std.ArrayList(u8),
    file_name: ?[]const u8,
    file: ?std.fs.File,

    pub fn create_buffer() Buffer {
        return Buffer
        {
            .arena = lhmem.make_arena((1<<10) * 24),
            .cursor_pos = 0,
            .mark_pos = 0,
            .buffer = std.ArrayList(u8).init(std.heap.page_allocator),
            .file_name = null,
            .file = null,
        };
    }

    pub fn open_or_create_file(buffer: *Buffer, path: []const u8) !void {
        buffer.file = std.fs.cwd().openFile(path, .{ .mode = .read_write, .lock = .none }) catch blk: {
            break :blk try std.fs.cwd().createFile(path, .{ .read = true });
        };
        if (buffer.file) |file| {
            buffer.file_name = path;
            buffer.cursor_pos = 0;
            buffer.mark_pos = buffer.cursor_pos;
            var buffered = std.io.bufferedReader(file.reader());
            const metadata = try file.metadata();
            try buffer.buffer.resize(metadata.size());
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

fn write_char(buf: *Buffer, c: u8) void {
    buf.buffer.insert(buf.cursor_pos, c) catch {};
    buf.cursor_pos += 1;
}

fn handle_key_input(buf: *Buffer, event: e.Event) void {
    switch(event.key) {
        .A => {
            if (event.mods & 0b010 == 1) {
                write_char(buf, 'A');
            } else {
                write_char(buf, 'a');
            }
        },

        else => {}
    }
    print("{s}\n", .{buf.buffer.items});
}

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

pub fn main() !void {
    if (__DEBUG__) {
        if (TARGET_OS == .windows) {
            _ = putenv("VK_INSTANCE_LAYERS=VK_LAYER_KHRONOS_validation;VK_LAYER_KHRONOS_profiles");
        } else {
            _ = putenv("VK_INSTANCE_LAYERS=VK_LAYER_KHRONOS_validation:VK_LAYER_KHRONOS_profiles");
        }
    }
    _ = Font;
    _ = FontAttributes;

    var app: Application = undefined;
    app.graphics_ctx.window = windowing.create_window("algo");
    app.graphics_ctx.vk_app.arena = lhmem.make_arena((1 << 10) * 100);
    app.graphics_ctx.vk_appdata.arena = lhmem.make_arena((1 << 10) * 100);
    try lhvk.init_vulkan(&app.graphics_ctx);
    var buffer: Buffer = Buffer.create_buffer();

    var quit: bool = false;
    while (!quit) {
        app.graphics_ctx.current_vertex_group = VertexList {
            .arena = lhmem.make_arena((1 << 10) * 20),
            .first = null,
            .last = null,

        };
        app.graphics_ctx.window.event.?.t = .E_NONE;
        app.graphics_ctx.window.get_events();
        if (app.graphics_ctx.window.event) |event| {
            switch (event.t) {
                .E_QUIT => quit = true,
                .E_KEY => {handle_key_input(&buffer, event);},
                else => {},
            }
        }
        app.graphics_ctx.window.event.?.t = .E_NONE;
        const rect = draw.Rect {.x = 0, .y = 0, .w = 12, .h = 12};
        draw.drawp_rectangle(&app.graphics_ctx, rect, draw.Color.create(0xff0000ff));
        if (lhvk.prepare_frame(&app.graphics_ctx)) continue;
        lhvk.begin_command_buffer_rendering(&app.graphics_ctx);
        lhvk.end_command_buffer_rendering(&app.graphics_ctx);
    }
    try buffer.save_file();
}
