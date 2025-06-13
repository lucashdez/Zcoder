const std = @import("std");
const assert = std.debug.assert;
const f_wl_connection = @import("wayland_connection.zig");
const WlHeader = f_wl_connection.WlHeader;
const Registry = @import("registry.zig").Registry;
const EventDataParser = @import("events.zig").EventDataParser;
const EventIt = @import("events.zig").EventIt;

const DisplayEvents = enum(i32) { err = 0 };

const DisplayOps = enum(u16) {
    sync = 0,
    get_registry = 1,
    fn val(self: *const DisplayOps) u16 {
        return @intFromEnum(self.*);
    }
};

const DisplayError = struct {
    object_id: u32,
    code: u32,
    message: []const u8,
    pub fn init(data: []const u8) !DisplayError {
        var it = EventDataParser{ .buf = data };
        return DisplayError{
            .object_id = try it.getU32(),
            .code = try it.getU32(),
            .message = try it.getString(),
        };
    }
};

pub const Display = struct {
    id: u32,

    pub fn init() Display {
        return Display{ .id = 1 };
    }

    pub fn handleEvent(self: *const Display, event: EventIt.Output) !void {
        _ = self;
        switch (event.header.op) {
            0 => {
                const err = try DisplayError.init(event.data);
                std.log.err("wl_display::error: object: {d}, code: {d}, msg: {s}", .{ err.object_id, err.code, err.message });
            },
            1 => {
                std.log.warn("Uninplemented handler for display::delete_id", .{});
            },
            else => {
                std.log.warn("Uninplemented error handler", .{});
            },
        }
    }

    pub fn getRegistry(self: *const Display, socket: std.posix.socket_t) !Registry {
        const new_id = 2;
        const GetRegistryMessage = packed struct {
            header: WlHeader,
            new_id: usize,
        };
        const msg = GetRegistryMessage{
            .header = .{
                .id = self.id,
                .op = DisplayOps.get_registry.val(),
                .size = @sizeOf(GetRegistryMessage),
            },
            .new_id = new_id,
        };
        const written = try std.posix.write(socket, std.mem.asBytes(&msg));
        assert(written == @sizeOf(GetRegistryMessage));
        return Registry{ .id = new_id };
    }

    pub fn sync(self: *const Display, socket: std.posix.socket_t, id: u32) !void {
        const SyncMessage = packed struct { header: WlHeader, new_id: usize };
        const msg = SyncMessage{ .header = .{ .id = self.id, .op = DisplayOps.sync.val(), .size = @sizeOf(SyncMessage) }, .new_id = id };
        std.time.sleep(1000000000);
        const written = try std.posix.write(socket, std.mem.asBytes(&msg));
        assert(written == @sizeOf(SyncMessage));
        var buf: [4096]u8 = undefined;

        var readed = try std.posix.read(socket, &buf);
        std.log.debug("SOMETHING, {d}", .{readed});
        while (readed == 0 ) {
            readed = try std.posix.read(socket, &buf);
        }
        var it = EventIt{ .buf = buf[0..readed] };
        std.log.info("Waiting for done()", .{});
        while (it.next()) |event| {
            if (event.header.id == id and event.header.op == 0) {
                break;
            }
        }
        std.log.info("done()", .{});
    }
};
