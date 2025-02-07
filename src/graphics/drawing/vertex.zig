const std = @import("std");
// Linear Algebra
const la = @import("../../lin_alg/la.zig");

// Vulkan and utils
const u = @import("../lhvk_utils.zig");
const vk = @import("../vk_api.zig").vk;

//memory
const lhmem = @import("../../memory/memory.zig");
const Arena = lhmem.Arena;

const Color = @import("primitives.zig").Color;

pub const RawVertex = struct {
    pos: [2]f32,
    color: [4]f32,
};

pub const VertexList = struct {
    arena: Arena,
    first: ?*Vertex,
    last: ?*Vertex,

    pub fn sll_push_back(list: *VertexList, new: *Vertex) void {
        if (list.first) |f| {
            if (f == list.last.?) { f.next = new; list.last = new; }
            else { list.last.?.next = new; list.last = new; }
        }
        else {list.first = new; list.last = new;}
    }
    pub fn count(list: *const VertexList)
    usize
    {
        var c: usize = 0;
        if (list.first) |head|
        {
            c = 1;
            var ptr: *Vertex = head;
            while(ptr.next) |next|
            {
                c += 1;
                ptr = next;
                if (ptr.next == null) {break;}
            }
        }
        return c;
    }
    pub fn compress(list: *VertexList, arena: *lhmem.Arena) []RawVertex {
        const n = list.count();
        const arr = arena.push_array(RawVertex, n)[0..n];
        var i: usize = 0;
        if (list.first) |head| {
            arr[i] = RawVertex {.pos = .{head.pos.x, head.pos.y}, .color = .{head.color.i,head.color.j,head.color.k,head.color.t}};
            i += 1;
            var ptr: *Vertex = head;
            while (ptr.next) |next|
            {
                ptr = next;
                arr[i] = RawVertex {.pos = .{ptr.pos.x, ptr.pos.y}, .color = .{ptr.color.i,ptr.color.j,ptr.color.k,ptr.color.t}};
            }
        }
        return arr;
    }
};

pub const VulkanVertex = struct {
    pos: [2]f32,
    color: [4]f32,

    pub fn init(p: la.Vec2f, c: la.Vec4f) VulkanVertex {
        return VulkanVertex{
            .pos = .{p.x, p.y}, .color = .{c.i,c.j,c.k,c.t},
        };
    }
    pub fn get_binding_description() vk.VkVertexInputBindingDescription {
        var description: vk.VkVertexInputBindingDescription = undefined;
        description.binding = 0;
        description.stride = @sizeOf(VulkanVertex);
        description.inputRate = vk.VK_VERTEX_INPUT_RATE_VERTEX;
        return description;
    }

    pub fn get_attribute_description(arena: *Arena) []vk.VkVertexInputAttributeDescription {
        var d: []vk.VkVertexInputAttributeDescription = arena.push_array(vk.VkVertexInputAttributeDescription, 2)[0..2];
        d[0].binding = 0;
        d[0].location = 0;
        d[0].format = vk.VK_FORMAT_R32G32_SFLOAT;
        d[0].offset = @offsetOf(VulkanVertex, "pos");

        d[1].binding = 0;
        d[1].location = 1;
        d[1].format = vk.VK_FORMAT_R32G32B32A32_SFLOAT;
        d[1].offset = @offsetOf(VulkanVertex, "color");

        return d;
    }

};

pub const Vertex = struct {
    pos: la.Vec2f,
    color: la.Vec4f,
    next: ?*Vertex,
    pub fn init(arena: *Arena, pos: la.Vec2f, c: Color) *Vertex {
        const v: *Vertex = &arena.push_array(Vertex, 1)[0];
        v.pos = pos;
        v.color = la.vec4f(
                @as(f32, @floatFromInt(c.r))/255,
                @as(f32, @floatFromInt(c.g))/255,
                @as(f32, @floatFromInt(c.b))/255,
                @as(f32, @floatFromInt(c.a))/255);
        v.next = null;
        return v;
    }
};