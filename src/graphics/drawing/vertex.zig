const la = @import("../../lin_alg/la.zig");
const u = @import("../lhvk_utils.zig");

//memory
const lhmem = @import("../../memory/memory.zig");
const Arena = lhmem.Arena;

const Color = @import("primitives.zig").Color;

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
    fn count(list: *const VertexList)
    usize
    {
        var c = 0;
        if (list.first) |head|
        {
            c = 1;
            var ptr: *Vertex = head;
            while(ptr.next) |next|
            {
                c += 1;
                ptr = next;
            }
        }
        return c;
    }
    pub fn compress(arena: lhmem.Arena, list: *VertexList) []VulkanVertex {
        const n = list.count();
        const arr = arena.push_array(VulkanVertex, n)[0..n];
        var i = 0;
        if (list.first) |head| {
            arr[i].pos = VulkanVertex.init(head.pos, head.color);
            i += 1;
            var ptr: *Vertex = head;
            while (ptr.next) |next|
            {
                ptr = next;
                arr[i].pos = VulkanVertex.init(ptr.pos, ptr.color);
            }
        }
    }
};

pub const VulkanVertex = struct {
    pos: la.Vec2f,
    color: la.Vec4f,
    pub fn init(p: la.Vec2f, c: la.Vec4f) VulkanVertex {
        return VulkanVertex{
            .pos = p, .color = c,
        };
    }
};

pub const Vertex = struct {
    pos: la.Vec2f,
    color: la.Vec4f,
    next: ?*Vertex,
    pub fn init(pos: la.Vec2f, c: Color) Vertex {
        return Vertex {
            .pos = pos,
            .color = la.vec4f(@floatFromInt(c.r),
                              @floatFromInt(c.g),
                              @floatFromInt(c.b),
                              @floatFromInt(c.a)),
            .next = null,
        };
    }
};