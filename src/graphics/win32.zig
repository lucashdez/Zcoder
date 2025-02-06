const std = @import("std");
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
    handle: ?*i32,
    instance: ?*anyopaque align(1),
    surface: ?*anyopaque align(1),
    display: ?*anyopaque,
    width: u32,
    height: u32,
    msg: raw.MSG,
    event: ?e.Event,

    pub fn get_events(window: *Window) void {
        if (raw.PeekMessageW(&window.msg, null, 0, 0, raw.PM_REMOVE) > 0) {
            var handled = false;
            _ = raw.TranslateMessage(&window.msg);
            switch (window.msg.message) {
                raw.WM_SYSKEYDOWN => {},
                raw.WM_SYSKEYUP => {},
                raw.WM_COMMAND => {},
                raw.WM_KEYDOWN => {
                    // TODO: Handle WM_CHAR;
                    _ = raw.PeekMessageW(&window.msg, null, 0, 0, raw.PM_REMOVE);
                    if (window.msg.message == raw.WM_CHAR) {u.warn("char pressed",.{});}
                    switch(window.msg.wParam) {
                        0x61 => {window.event.?.t = .E_KEY; window.event.?.key = .A;},
                        else => {
                            u.warn("KEY not handled = {}", .{window.msg.wParam});
                        }
                    }
                },
                raw.WM_KEYUP => {
                    _ = raw.PeekMessageW(&window.msg, null, 0, 0, raw.PM_REMOVE);
                },
                raw.WM_NCLBUTTONDOWN => {
                    switch (window.msg.wParam) {
                        raw.HTCLOSE => {
                            handled = true;
                            raw.PostQuitMessage(0);
                        },
                        raw.HTLEFT => u.info("Left resize edge", .{}),
                        raw.HTRIGHT => u.info("Right resize edge", .{}),
                        raw.HTTOP => u.info("Top resize edge", .{}),
                        raw.HTBOTTOM => u.info("Bottom resize edge", .{}),
                        raw.HTTOPLEFT => u.info("Top-left resize corner", .{}),
                        raw.HTTOPRIGHT => u.info("Top-right resize corner", .{}),
                        raw.HTBOTTOMLEFT => u.info("Bottom-left resize corner", .{}),
                        raw.HTBOTTOMRIGHT => u.info("Bottom-right resize corner", .{}),
                        else => u.info("Non-client area clicked: {}", .{window.msg.wParam}),
                    }
                },
                raw.WM_CLOSE => {
                    u.info("CLOSE", .{});
                    handled = true;
                },
                raw.WM_SIZE => {
                    u.info("SIZE", .{});
                    const width: i32 = @intCast(window.msg.lParam & 0xFFFF); // Low word (width)
                    const height: i32 = @intCast((window.msg.lParam >> 16) & 0xFFFF); // High word (height)
                    u.info("Window resized: {}x{}", .{ width, height });
                },
                raw.WM_PAINT => {},
                raw.WM_DESTROY => {
                    u.info("DESTROY", .{});
                },
                raw.WM_QUIT => {
                    window.event.?.t = .E_QUIT;
                    handled = true;
                },
                raw.WM_SIZING => {
                    u.info("Resizing window interactively: {}", .{window.msg.wParam});
                },
                raw.WM_MOUSEMOVE => {
                    const x: i32 = @intCast(window.msg.lParam & 0xFFFF); // Low word (width)
                    const y: i32 = @intCast((window.msg.lParam >> 16) & 0xFFFF); // High word (height)
                    u.info("MOUSE: {}x{}", .{ x, y });
                },
                raw.WM_NCMOUSEMOVE => {
                    const x: i32 = @intCast(window.msg.lParam & 0xFFFF); // Low word (width)
                    const y: i32 = @intCast((window.msg.lParam >> 16) & 0xFFFF); // High word (height)
                    u.info("NCMOUSE: {}x{}", .{ x, y });
                },
                else => {
                    u.warn("Not handled: {}", .{window.msg.message});
                },
            }
            if (!handled) _ = raw.DefWindowProcW(window.msg.hwnd, window.msg.message, window.msg.wParam, window.msg.lParam);
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
    const hwnd_opt: ?raw.HWND = raw.CreateWindowExW(.{}, class_name, W("Learn to program"), styles, raw.CW_USEDEFAULT, raw.CW_USEDEFAULT, width, height, null, null, hinstance, null);
    assert(hwnd_opt != null);
    const hwnd = hwnd_opt.?;

    _ = raw.ShowWindow(hwnd, raw.SW_SHOW);
    return Window{
        .handle = null,
        .instance = hinstance,
        .surface = hwnd,
        .display = null,
        .width = width,
        .height = height,
        .msg = std.mem.zeroes(raw.MSG),
        .event = std.mem.zeroes(e.Event),
    };
}
