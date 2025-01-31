const std = @import("std");
const sdl = @cImport(@cInclude("SDL2/SDL.h"));
const raw = @import("../os/win32/win32/everything.zig");
const u = @import("lhvk_utils.zig");
const e = @import("windowing/events.zig");
const lhmem = @import("../memory/memory.zig");
const W = std.unicode.utf8ToUtf16LeStringLiteral;
const assert = std.debug.assert;

var got_something_useful: i32 = 0;

fn customproc(
    hwnd: ?raw.HWND,
    msg: u32,
    wParam: raw.WPARAM,
    lParam: raw.LPARAM,
) callconv(std.os.windows.WINAPI) raw.LRESULT {
    return raw.DefWindowProcW(hwnd, msg, wParam, lParam);
}



pub const Window = struct {
    handle: ?*sdl.SDL_Window,
    instance: ?*anyopaque align(1),
    surface:  ?*anyopaque align(1),
    display: ?*anyopaque,
    width: u32,
    height: u32,
    msg: raw.MSG,
    events: e.EventList,

    pub fn get_events(window: *Window)
    void
    {
        if (raw.PeekMessageW(&window.msg, null, 0, 0, raw.PM_REMOVE) > 0)
        {
            switch(window.msg.message)
            {

            }
        }
    }
};

pub fn create_window(comptime name: []const u8) Window {
    const class_name: [*:0]const u16 = W(name);
    const hinstance: raw.HINSTANCE = raw.GetModuleHandleW(null).?;
    const width: i32 = 800;
    const height: i32 = 600;
    var wc: raw.WNDCLASSW = std.mem.zeroes(raw.WNDCLASSW);
    wc.lpfnWndProc = customproc;
    wc.hInstance = hinstance;
    wc.lpszClassName = class_name;
    _ = raw.RegisterClassW(&wc);
    const styles = raw.WINDOW_STYLE{
        .VISIBLE = 1,
        .TABSTOP = 1,
        .GROUP = 1,
        .THICKFRAME = 1,
        .SYSMENU = 1,
        .DLGFRAME = 1,
        .BORDER = 1,
    };
    const hwnd: ?raw.HWND = raw.CreateWindowExW(
        .{},
        class_name,
        W("Learn to program"),
        styles,
        raw.CW_USEDEFAULT, raw.CW_USEDEFAULT, width, height,
        null,
        null,
        hinstance,
        null);
    assert(hwnd != null);
    _ = raw.ShowWindow(hwnd.?, raw.SW_SHOW);
    return Window {
        .handle = null,
        .instance = hinstance,
        .surface =  hwnd.?,
        .display =  null,
        .width = width,
        .height = height,
        .msg = std.mem.zeroes(raw.MSG),
        .events = e.EventList {.arena = lhmem.make_arena((1 << 10) * 24), .first = null, .last = null},
    };
}