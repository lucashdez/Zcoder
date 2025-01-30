const lhmem = @import("../../memory/memory.zig");

pub const EventType = enum(u32) {
    E_QUIT,
    E_RESIZE,
};

pub const Event = struct {
    t: EventType,
    params: u32,
    next: ?*Event,
};

pub const EventList = struct {
    arena: lhmem.Arena,
    first: ?*Event,
    last: ?*Event,
};