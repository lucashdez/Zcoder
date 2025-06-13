const std = @import("std");
const WlHeader = @import("wayland_connection.zig").WlHeader;


pub const EventIt = struct {
    buf: []const u8,
    pub const Output = struct {
        header: WlHeader,
        data: []const u8,
    };

    pub fn next(self: *EventIt) ?Output {
        const header_size = @sizeOf(WlHeader);
        if (self.buf.len == 0) {
            return null;
        }
        const header_bytes = self.buf[0..header_size];
        const header = std.mem.bytesAsValue(WlHeader, header_bytes);

        if (self.buf.len < header.size) {
            return null;
        }

        const data = self.buf[header_size..header.size];
        self.consume(header.size);

        return Output{
            .header = header.*,
            .data = data,
        };
    }

    fn consume(self: *EventIt, len: usize) void {
        if (self.buf.len == len) {
            self.buf = &.{};
        } else {
            self.buf = self.buf[len..];
        }
    }
};


pub const EventDataParser = struct {
    buf: []const u8,

    fn roundUp(val: anytype, mul: @TypeOf(val)) @TypeOf(val) {
        return ((val - 1) / mul + 1) * mul;
    }

    pub fn getU32(self: *EventDataParser) !u32 {
        if (self.buf.len < 4) return error.InvalidLen;
        const val = std.mem.bytesToValue(u32, self.buf[0..4]);
        self.consume(4);
        return val;
    }

    pub fn getString(self: *EventDataParser) ![]const u8 {
        if (self.buf.len < 4) return error.InvalidLen;
        const len = std.mem.bytesToValue(u32, self.buf[0..4]);
        const consume_len = 4 + roundUp(len, 4);
        const s = self.buf[4 .. 4 + len - 1];
        if (consume_len > self.buf.len) {
            return error.InvalidLen;
        }
        self.consume(consume_len);
        return s;
    }

    fn consume(self: *EventDataParser, len: usize) void {
        if (self.buf.len == len) {
            self.buf = &.{};
        } else {
            self.buf = self.buf[len..];
        }
    }
};
