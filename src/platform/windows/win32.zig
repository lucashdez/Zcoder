const std = @import("std");
const raw = @import("../../os/win32/win32/everything.zig");
const u = @import("../../graphics/lhvk_utils.zig");
const wideString = std.unicode.utf8ToUtf16LeStringLiteral;

fn customproc(
    hwnd: ?raw.HWND,
    msg: u32,
    wParam: raw.WPARAM,
    lParam: raw.LPARAM,
) callconv(std.os.windows.WINAPI) raw.LRESULT {
    return raw.DefWindowProcW(hwnd, msg, wParam, lParam);
}

pub const RawWindow = struct
{
    hInstance: ?raw.HINSTANCE,
    hwnd: ?raw.HWND,

    pub fn
    init(name: []const u8, width: i32, height: i32) RawWindow
    {
        const class_name: [*:0]const u16 = wideString(name);
        const hInstance: raw.HINSTANCE = raw.GetModuleHandleW(null);
        var wc: raw.WNDCLASSW = std.mem.zeroes(raw.WNDCLASSW);
        wc.lpfnWndProc = customproc;
        wc.hInstance = hInstance;
        wc.lpszClassName = class_name;
        _ = raw.RegisterClassW(&wc);
        const styles = raw.WINDOW_STYLE {
            .VISIBLE = 1,
            .TABSTOP = 1,
            .GROUP = 1,
            THICKFRAME = 1,
        };

        return RawWindow { .hInstance = null, .hwnd = null};
    }
};