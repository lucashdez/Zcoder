const std = @import("std");
const EventDataParser = @import("events.zig").EventDataParser;

pub fn parseDataResponse(comptime T: type, data: []const u8) !T {
    var ret: T = undefined;
    var it = EventDataParser{ .buf = data };
    inline for (std.meta.fields(T)) |field| {
        switch (field.type) {
            u32 => {
                @field(ret, field.name) = try it.getU32();
            },
            []const u8 => {
                @field(ret, field.name) = try it.getString();
            },
            else => {
                std.log.err("Kind of type not in Type", .{});
            },
        }
    }
    return ret;
}
