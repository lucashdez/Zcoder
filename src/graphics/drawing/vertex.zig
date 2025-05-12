const std = @import("std");
// Linear Algebra
const la = @import("../../lin_alg/la.zig");

// Vulkan and utils
const u = @import("../lhvk_utils.zig");
const vk = @import("../vk_api.zig").vk;

//memory
const lhmem = @import("../../memory/memory.zig");
const Arena = lhmem.Arena;

// primitives
const Color = @import("primitives.zig").Color;

// base
const base = @import("../../base/base_types.zig");

const VertexType = enum(u32) { VtTriangle, VtRectangle };

pub const RawVertex = struct {
    pos: [2]f32,
    color: [4]f32,
};

pub const VertexGroup = struct {
    first: ?*VertexList,
    last: ?*VertexList,
    pub fn sll_push_back(list: *VertexGroup, new: *VertexList) void {
        if (list.first) |f| {
            if (f == list.last.?) {
                f.next = new;
                list.last = new;
            } else {
                list.last.?.next = new;
                list.last = new;
            }
        } else {
            list.first = new;
            list.last = new;
        }
    }

    pub fn count(list: *const VertexGroup) usize {
        var c: usize = 0;
        if (list.first) |head| {
            c = 1;
            var ptr: *VertexList = head;
            while (ptr.next) |next| {
                c += 1;
                ptr = next;
                if (ptr.next == null) {
                    break;
                }
            }
        }
        return c;
    }

    pub fn compress(group: *VertexGroup, arena: *lhmem.Arena) []RawVertex {
        var list: ?*VertexList = group.first;
        var total_size: usize = 0;
        const start_ptr: [*]const u8 = arena.mem;
        while (list) |l| {
            const n = l.count();
            total_size += n;
            const arr = arena.push_array(RawVertex, n)[0..n];
            var i: usize = 0;
            var ptr = l.first;

            while (ptr) |aval| {
                arr[i] = aval.raw;
                ptr = aval.next;
                i += 1;
            }
            list = l.next;
        }
        return @as([*]RawVertex, @constCast(@alignCast(@ptrCast(start_ptr))))[0..total_size];
    }
};

pub const VertexList = struct {
    arena: Arena,
    first: ?*Vertex,
    last: ?*Vertex,
    next: ?*VertexList,

    pub fn sll_push_back(list: *VertexList, new: *Vertex) void {
        if (list.first) |f| {
            if (f == list.last.?) {
                f.next = new;
                list.last = new;
            } else {
                list.last.?.next = new;
                list.last = new;
            }
        } else {
            list.first = new;
            list.last = new;
        }
    }
    pub fn count(list: *const VertexList) usize {
        var c: usize = 0;
        if (list.first) |head| {
            c = 1;
            var ptr: *Vertex = head;
            while (ptr.next) |next| {
                c += 1;
                ptr = next;
                if (ptr.next == null) {
                    break;
                }
            }
        }
        return c;
    }
    pub fn compress(list: *VertexList, arena: *lhmem.Arena) []RawVertex {
        const n = list.count();
        const arr = arena.push_array(RawVertex, n)[0..n];
        var i: usize = 0;
        var ptr = list.first;
        while (ptr) |aval| {
            arr[i] = aval.raw;
            ptr = aval.next;
            i += 1;
        }
        return arr;
    }
};


// TODO: Here you have to do the binding of the uv and other things in the Font Beziers 
pub fn get_binding_description() vk.VkVertexInputBindingDescription {
    var description: vk.VkVertexInputBindingDescription = undefined;
    description.binding = 0;
    description.stride = @sizeOf(RawVertex);
    description.inputRate = vk.VK_VERTEX_INPUT_RATE_VERTEX;
    return description;
}

pub fn get_attribute_description(arena: *Arena) []vk.VkVertexInputAttributeDescription {
    var d: []vk.VkVertexInputAttributeDescription = arena.push_array(vk.VkVertexInputAttributeDescription, 2)[0..2];
    d[0].binding = 0;
    d[0].location = 0;
    d[0].format = vk.VK_FORMAT_R32G32_SFLOAT;
    d[0].offset = @offsetOf(RawVertex, "pos");

    d[1].binding = 0;
    d[1].location = 1;
    d[1].format = vk.VK_FORMAT_R32G32B32A32_SFLOAT;
    d[1].offset = @offsetOf(RawVertex, "color");

    return d;
}

pub const Vertex = struct {
    raw: RawVertex,
    next: ?*Vertex,
    pub fn init(arena: *Arena, pos: la.Vec2f, c: Color) *Vertex {
        const v: *Vertex = &arena.push_array(Vertex, 1)[0];
        v.raw.pos[0] = pos.x;
        v.raw.pos[1] = pos.y;

        v.raw.color = .{ c.r, c.g, c.b, c.a };
        v.next = null;
        return v;
    }
};
