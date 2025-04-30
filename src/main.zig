const __DEBUG__: bool = true;
const std = @import("std");
const TARGET_OS = @import("builtin").os.tag;
const zigimg = @import("zigimg");
const Font = @import("font/font.zig");
const GeneratedGlyph = @import("font/glyf.zig").GeneratedGlyph;
const FontAttributes = Font.FontAttributes;
const lhmem = @import("memory/memory.zig");
const Arena = lhmem.Arena;
const lhvk = @import("graphics/lhvk.zig");
const windowing = if (@import("builtin").os.tag == .windows) @import("graphics/win32.zig") else @import("graphics/x.zig");
const e = @import("graphics/windowing/events.zig");
const la = @import("lin_alg/la.zig");
const print = std.debug.print;
const draw = @import("graphics/drawing/primitives.zig");
const v = @import("graphics/drawing/vertex.zig");
const VertexList = v.VertexList;
const VertexGroup = v.VertexGroup;
const base = @import("base/base_types.zig");
const Rectu32 = base.Rectu32;

extern fn putenv(string: [*:0]const u8) c_int;

const Application = struct {
    graphics_ctx: lhvk.LhvkGraphicsCtx,
    font: FontAttributes,
};

const Buffer = struct {
    arena: Arena,
    cursor_pos: usize,
    mark_pos: usize,
    buffer: std.ArrayList(u8),
    file_name: ?[]const u8,
    file: ?std.fs.File,

    pub fn create_buffer() Buffer {
        return Buffer{
            .arena = lhmem.make_arena((1 << 10) * 24),
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
    write_char(buf, @as(u8, @intCast(event.char)));
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

fn load_font(app: *Application, name: []const u8) !void {
    app.font = try Font.load_font(name);
}

pub fn main() !void {
    if (__DEBUG__) {
        if (TARGET_OS == .windows) {
            _ = putenv("VK_INSTANCE_LAYERS=VK_LAYER_KHRONOS_validation;VK_LAYER_KHRONOS_profiles");
        } else {
            _ = putenv("VK_INSTANCE_LAYERS=VK_LAYER_KHRONOS_validation:VK_LAYER_KHRONOS_profiles");
        }
    }
    var app: Application = undefined;
    app.graphics_ctx.vk_app.arena = lhmem.make_arena((1 << 10) * 100);
    app.graphics_ctx.vk_appdata.arena = lhmem.make_arena((1 << 10) * 100);
    const thr = try std.Thread.spawn(.{}, load_font, .{ &app, "Envy Code R.ttf" });

    app.graphics_ctx.window = windowing.create_window("algo");
    try lhvk.init_vulkan(&app.graphics_ctx);
    var buffer: Buffer = Buffer.create_buffer();

    var quit: bool = false;
    while (!quit) {
        var frame_arena: Arena = lhmem.make_arena(lhmem.KB(16));
        app.graphics_ctx.current_vertex_group = VertexGroup{
            .first = null,
            .last = null,
        };
        app.graphics_ctx.window.get_events();
        if (app.graphics_ctx.window.event) |event| {
            switch (event.t) {
                .E_QUIT => quit = true,
                .E_KEY => {
                    handle_key_input(&buffer, event);
                },
                else => {},
            }
            app.graphics_ctx.window.event.?.t = .E_NONE;
        }
        app.graphics_ctx.window.event.?.t = .E_NONE;
        var glyph_: ?GeneratedGlyph = null;
        if (buffer.buffer.items.len > 0) {
            glyph_ = app.font.face.glyphs[buffer.buffer.items[buffer.buffer.items.len - 1]];
        }


        if (glyph_) |glyph| {
            var j: usize = 0;
            for (0..glyph.end_indexes_for_strokes.len) |i| {
                var list_ptr: *VertexList = frame_arena.push_item(VertexList);
                list_ptr.arena = lhmem.scratch_block();
                app.graphics_ctx.current_vertex_group.sll_push_back(list_ptr);

                while (j < (glyph.end_indexes_for_strokes[i])) {
                    const p: la.Vec2f = glyph.vertex[j];
                    draw.drawp_vertex(&app.graphics_ctx, list_ptr, .{ .x = p.x / 8, .y = p.y / 8 }, draw.Color.create(0xFFFFFFFF));
                    j += 1;
                }
            }
        }

        if (try lhvk.prepare_frame(&app.graphics_ctx)) continue;
        lhvk.begin_command_buffer_rendering(&app.graphics_ctx);
        try lhvk.end_command_buffer_rendering(&app.graphics_ctx);
    }
    thr.join();

    try buffer.save_file();
}
