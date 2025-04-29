const std = @import("std");
const raw = @import("../os/win32/win32/everything.zig");
const u = @import("lhvk_utils.zig");
const e = @import("windowing/events.zig");
const lhmem = @import("../memory/memory.zig");
const W = std.unicode.utf8ToUtf16LeStringLiteral;
const assert = std.debug.assert;
const base = @import("../base/base_types.zig");
const Rectu32 = base.Rectu32;

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
                    if (window.msg.message == raw.WM_CHAR) {
                        window.event.?.t = .E_KEY;
                    }
                    switch (window.msg.wParam) {
                        0x10 => {
                            window.event.?.mods |= 0b010;
                        },
                        0x61, 0x41  => {
                            window.event.?.key = .A;
                        },
                        0x62, 0x42 => {
                            window.event.?.key = .B;
                        },
                        0x63, 0x43 => {
                            window.event.?.key = .C;
                        },
                        else => {
                            u.warn("KEY not handled = 0x{x}", .{window.msg.wParam});
                        },
                    }
                },
                raw.WM_KEYUP => {
                    _ = raw.PeekMessageW(&window.msg, null, 0, 0, raw.PM_REMOVE);
                    switch (window.msg.wParam) {
                        0x10 => {
                            window.event.?.mods &= 0b101;
                        },
                        else => {
                            u.warn("key unpressed : 0x{x}", .{window.msg.wParam});
                        }
                    }
                },
                raw.WM_NCLBUTTONDOWN => {
                    switch (window.msg.wParam) {
                        raw.HTCLOSE => {
                            handled = true;
                            raw.PostQuitMessage(0);
                        },
                        else => {},
                    }
                },
                raw.WM_NCLBUTTONUP => {
                    switch (window.msg.wParam) {
                        else => u.info("Non-client area clicked: {}", .{window.msg.wParam}),
                    }
                },
                raw.WM_CLOSE => {
                    u.info("CLOSE", .{});
                    handled = true;
                },
                raw.WM_SIZE => {},
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
                else => {},
            }
            if (!handled) {
                _ = raw.DefWindowProcW(window.msg.hwnd, window.msg.message, window.msg.wParam, window.msg.lParam);
            }
        }
    }

    pub fn get_size(window: *const Window) Rectu32 {
        var rect: raw.RECT = undefined;
        _ = raw.GetClientRect(@alignCast(@ptrCast(window.surface.?)), &rect);
        const ret = Rectu32{
            .size = .{
                .width = @abs(rect.right - rect.left),
                .height = @abs(rect.bottom - rect.top),
                .pos = .{ .v = .{ 0, 0 } },
            },
        };
        return ret;
    }
};

pub fn create_window(comptime name: []const u8) Window {
    const class_name: [*:0]const u16 = W(name);
    const hinstance: raw.HINSTANCE = raw.GetModuleHandleW(null).?;
    var width: u32 = 800;
    var height: u32 = 600;
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
    const hwnd_opt: ?raw.HWND = raw.CreateWindowExW(.{}, class_name, W("Learn to program"), styles, raw.CW_USEDEFAULT, raw.CW_USEDEFAULT, @intCast(width), @intCast(height), null, null, hinstance, null);
    assert(hwnd_opt != null);
    const hwnd = hwnd_opt.?;
    var rect: raw.RECT = undefined;
    _ = raw.GetClientRect(hwnd, &rect);
    width = @abs(rect.right - rect.left);
    height = @abs(rect.bottom - rect.top);

    _ = raw.ShowWindow(hwnd, raw.SW_SHOW);
    return Window{
        .handle = null,
        .instance = hinstance,
        .surface = hwnd,
        .display = null,
        .msg = std.mem.zeroes(raw.MSG),
        .event = std.mem.zeroes(e.Event),
    };
}
