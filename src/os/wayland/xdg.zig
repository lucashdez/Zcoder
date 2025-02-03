pub const xdg_wm_base = struct {};

pub const xdg_wm_base_err = enum(u32) {
    role = 0,
    defunct_surfaces = 1,
    not_the_topmost_popup = 2,
};
