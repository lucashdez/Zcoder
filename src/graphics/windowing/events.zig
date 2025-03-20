const lhmem = @import("../../memory/memory.zig");

pub const KEY_PRESSED = enum(u32) {
    @"0",
    @"1",
    @"2",
    @"3",
    @"4",
    @"5",
    @"6",
    @"7",
    @"8",
    @"9",
    A,
    B,
    C,
    D,
    E,
    F,
    G,
    H,
    I,
    J,
    K,
    L,
    M,
    N,
    O,
    P,
    Q,
    R,
    S,
    T,
    U,
    V,
    W,
    X,
    Y,
    Z,
};

pub const EventType = enum(u32) {
    E_NONE,
    E_QUIT,
    E_RESIZE,
    E_KEY,
};

pub const Event = struct {
    t: EventType,
    params: u32,
    key: KEY_PRESSED,
    // 0b000 <- none
    // 0b001 <- CTRL
    // 0b010 <- SHIFT
    // 0b100 <- ALT
    mods: u3,
};
