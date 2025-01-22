const tagWNDCLASSW = struct {
   style: u32,
   lpfnWndProc: fn (?*anyopaque, usize, usize, isize) isize,
   cbClsExtra: i32,
   cbWndExtra: i32,
   hInstance: ?*anyopaque,
   hIcon: ?*anyopaque,
   hCursor: ?*anyopaque,
   hbrBackground: ?*anyopaque,
   lpszMenuName: []const u8,
   lpszClassName: []const u8,
};

const WNDCLASSW  = tagWNDCLASSW;
const PWNDCLASSW = ?*tagWNDCLASSW;
const NPWNDCLASSW = ?*tagWNDCLASSW;
const LPWNDCLASSW = ?*tagWNDCLASSW;

