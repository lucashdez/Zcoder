// CONSTANTS

pub const WS_BORDER: u32 = 0x00800000;
pub const WS_CAPTION: u32 = 0x00C00000;
pub const WS_CHILD: u32 = 0x40000000;
pub const WS_CHILDWINDOW: u32 = 0x40000000;
pub const WS_CLIPCHILDREN: u32 = 0x02000000;
pub const WS_CLIPSIBLINGS: u32 = 0x04000000;
pub const WS_DISABLED: u32 = 0x08000000;
pub const WS_DLGFRAME: u32 = 0x00400000;
pub const WS_GROUP: u32 = 0x00020000;
pub const WS_HSCROLL: u32 = 0x00100000;
pub const WS_ICONIC: u32 = 0x20000000;
pub const WS_MAXIMIZE: u32 = 0x01000000;
pub const WS_MAXIMIZEBOX: u32 = 0x00010000;
pub const WS_MINIMIZE: u32 = 0x20000000;
pub const WS_MINIMIZEBOX: u32 = 0x00020000;
pub const WS_OVERLAPPED: u32 = 0x00000000;
pub const WS_OVERLAPPEDWINDOW: u32 = (WS_OVERLAPPED | WS_CAPTION | WS_SYSMENU | WS_THICKFRAME | WS_MINIMIZEBOX | WS_MAXIMIZEBOX);
pub const WS_POPUP: u32 = 0x80000000;
pub const WS_POPUPWINDOW: u32 = (WS_POPUP | WS_BORDER | WS_SYSMENU);
pub const WS_SIZEBOX: u32 = 0x00040000;
pub const WS_SYSMENU: u32 = 0x00080000;
pub const WS_TABSTOP: u32 = 0x00010000;
pub const WS_THICKFRAME: u32 = 0x00040000;
pub const WS_TILED: u32 = 0x00000000;
pub const WS_TILEDWINDOW: u32 = (WS_OVERLAPPED | WS_CAPTION | WS_SYSMENU | WS_THICKFRAME | WS_MINIMIZEBOX | WS_MAXIMIZEBOX);
pub const WS_VISIBLE: u32 = 0x10000000;
pub const WS_VSCROLL: u32 = 0x00200000;

// STRUCTS
const tagWNDCLASSA = struct {
   style: u32,
   lpfnWndProc: ?*const fn (?*anyopaque, usize, usize, isize) callconv(.C) isize,
   cbClsExtra: i32,
   cbWndExtra: i32,
   hInstance: ?*anyopaque,
   hIcon: ?*anyopaque,
   hCursor: ?*anyopaque,
   hbrBackground: ?*anyopaque,
   lpszMenuName: ?[*]const u8,
   lpszClassName: ?[*]const u8,
};

pub const WNDCLASSA  = tagWNDCLASSA;
pub const PWNDCLASSA = ?*tagWNDCLASSA;
pub const NPWNDCLASSA = ?*tagWNDCLASSA;
pub const LPWNDCLASSA = ?*tagWNDCLASSA;

// FUNCTIONS
pub extern fn DefWindowProcA(hwnd: ?*anyopaque, uMsg: usize, wParam: usize , lParam: isize ) isize;
pub extern fn GetModuleHandleA(lpModuleHandle: ?[*]const u8) ?*anyopaque;
pub extern fn CreateWindowExA(dwExStyle: u32, lpClassName: ?[*]const u8, lpWindowName: ?[*]const u8, dwStyle: u32, X: i32, Y: i32, nWidth: i32, nHeight: i32, hWndParent: ?*anyopaque, hMenu: ?*anyopaque, hInstance: ?*anyopaque, lpParam: ?*anyopaque
) ?*anyopaque;
pub extern fn RegisterClassA(wc: ?*const WNDCLASSA) u16;
pub extern fn GetLastError() u32;

