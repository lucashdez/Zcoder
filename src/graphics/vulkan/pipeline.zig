const std = @import("std");
const vk = @import("../vk_api.zig").vk;
const lhmem = @import("../../memory/memory.zig");
const Arena = lhmem.Arena;
const u = @import("../lhvk_utils.zig");
const v = @import("../drawing/vertex.zig");
const font_v = @import("../drawing/text.zig");
const Swapchain = @import("swapchain.zig").Swapchain;

// TODO: Create the posibility of multiple pipelines, and shader objects
// The need for uv coordinates in the binding and attribute descriptions is
// essential for this project to continue moving forward. Also, linux pls

fn read_file(arena: *lhmem.Arena, file_name: []const u8) ![]const u8 {
    var file = std.fs.cwd().openFile(file_name, .{}) catch {
        var arena_int = std.heap.ArenaAllocator.init(std.heap.page_allocator);
        defer arena_int.deinit();
        const alloc = arena_int.allocator();
        const dir = try std.fs.cwd().realpathAlloc(alloc, ".");
        u.err("File not Found at: {s}{s}", .{ dir, file_name });
        return error.FileNotFound;
    };
    const metadata = try file.metadata();
    const size = metadata.size();
    const buff: []u8 = arena.push_array(u8, size)[0..size];
    const reader = file.reader();
    try reader.readNoEof(@constCast(buff));
    return buff;
}

fn create_shader_module(device: vk.VkDevice, code: []const u8) ?vk.VkShaderModule {
    var create_info: vk.VkShaderModuleCreateInfo = .{
        .sType = vk.VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO,
        .codeSize = code.len,
        .pCode = @alignCast(@ptrCast(code.ptr)),
    };
    var shader_module: vk.VkShaderModule = undefined;
    if (vk.vkCreateShaderModule(device, &create_info, null, &shader_module) != vk.VK_SUCCESS) return null;
    return shader_module;
}

pub const PipelineOptions = struct {
    topology: vk.VkPrimitiveTopology,
    frag_path: []const u8,
    vert_path: []const u8,
};

pub const Pipeline = struct {
    arena: lhmem.Arena,
    pipeline: vk.VkPipeline,
    layout: vk.VkPipelineLayout,
    pub fn init(device: vk.VkDevice, render_pass: vk.VkRenderPass, swapchain: Swapchain, p_opt: PipelineOptions) !Pipeline {
        var arena = lhmem.make_arena((1 << 10) * 24);
        const pipeline_layout = create_pipeline_layout(device);
        const pipeline = try create_pipeline(&arena, device, render_pass, swapchain, pipeline_layout, p_opt);
        return .{ .arena = arena, .pipeline = pipeline, .layout = pipeline_layout };
    }

    pub fn init_font(device: vk.VkDevice, render_pass: vk.VkRenderPass, swapchain: Swapchain, p_opt: PipelineOptions) !Pipeline {
        var arena = lhmem.make_arena((1 << 10) * 24);
        const pipeline_layout = create_pipeline_layout(device);
        const pipeline = try create_font_pipeline(&arena, device, render_pass, swapchain, pipeline_layout, p_opt);
        return .{ .arena = arena, .pipeline = pipeline, .layout = pipeline_layout };
    }


    fn create_pipeline_layout(device: vk.VkDevice) vk.VkPipelineLayout {
        var pipeline_layout_create_info = std.mem.zeroes(vk.VkPipelineLayoutCreateInfo);
        pipeline_layout_create_info.sType = vk.VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO;
        pipeline_layout_create_info.pNext = null;
        pipeline_layout_create_info.flags = 0;
        pipeline_layout_create_info.setLayoutCount = 0;
        pipeline_layout_create_info.pSetLayouts = null;
        pipeline_layout_create_info.pushConstantRangeCount = 0;
        pipeline_layout_create_info.pPushConstantRanges = null;

        var layout: vk.VkPipelineLayout = undefined;
        if (vk.vkCreatePipelineLayout(device, &pipeline_layout_create_info, null, &layout) != vk.VK_SUCCESS) {
            u.err("SOMETHING HERE IN THE CREATING OF LAYOUT", .{});
        }
        return layout;
    }

    fn create_pipeline(arena: *lhmem.Arena, device: vk.VkDevice, render_pass: vk.VkRenderPass, swapchain: Swapchain, pipeline_layout: vk.VkPipelineLayout, p_opt: PipelineOptions) !vk.VkPipeline {
        var scratch = lhmem.scratch_block();
        const vert_bytes = try read_file(&scratch, p_opt.vert_path);
        const frag_bytes = try read_file(&scratch, p_opt.frag_path);
        const vert_shader = create_shader_module(device, vert_bytes).?;
        defer vk.vkDestroyShaderModule(device, vert_shader, null);
        const frag_shader = create_shader_module(device, frag_bytes).?;
        defer vk.vkDestroyShaderModule(device, frag_shader, null);

        var vssci = std.mem.zeroes(vk.VkPipelineShaderStageCreateInfo);
        vssci.sType = vk.VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO;
        vssci.stage = vk.VK_SHADER_STAGE_VERTEX_BIT;
        vssci.module = vert_shader;
        vssci.pName = "main";

        var fssci = std.mem.zeroes(vk.VkPipelineShaderStageCreateInfo);
        fssci.sType = vk.VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO;
        fssci.stage = vk.VK_SHADER_STAGE_FRAGMENT_BIT;
        fssci.module = frag_shader;
        fssci.pName = "main";

        const stage_infos: [2]vk.VkPipelineShaderStageCreateInfo = .{ vssci, fssci };

        var vertex_input_info: vk.VkPipelineVertexInputStateCreateInfo = std.mem.zeroes(vk.VkPipelineVertexInputStateCreateInfo);
        vertex_input_info.sType = vk.VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO;

        // NOTE:(lucashdez) HEREEE DYNAMIC
        var binding_description = v.get_binding_description();
        const attribute_description = v.get_attribute_description(arena);
        vertex_input_info.vertexBindingDescriptionCount = 1;
        vertex_input_info.vertexAttributeDescriptionCount = @intCast(attribute_description.len);
        vertex_input_info.pVertexBindingDescriptions = &binding_description;
        vertex_input_info.pVertexAttributeDescriptions = attribute_description.ptr;

        var input_assembly_create_info: vk.VkPipelineInputAssemblyStateCreateInfo =  undefined;
        input_assembly_create_info.sType = vk.VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO;
        input_assembly_create_info.pNext = null;
        input_assembly_create_info.flags = 0;
        input_assembly_create_info.topology = p_opt.topology;
        input_assembly_create_info.primitiveRestartEnable = vk.VK_FALSE;

        // TODO: Dynamic Viewport
        var viewport: vk.VkViewport = std.mem.zeroes(vk.VkViewport);
        viewport.x = 0.0;
        viewport.y = 0.0;
        viewport.width = @as(f32, @floatFromInt(swapchain.extent.width));
        viewport.height = @as(f32, @floatFromInt(swapchain.extent.height));
        viewport.minDepth = 0.0;
        viewport.maxDepth = 1.0;

        var scissor: vk.VkRect2D = std.mem.zeroes(vk.VkRect2D);
        var offset: vk.VkOffset2D = std.mem.zeroes(vk.VkOffset2D);
        offset.x = 0;
        offset.y = 0;
        scissor.offset = offset;
        scissor.extent = swapchain.extent;

        var viewport_state_create_info: vk.VkPipelineViewportStateCreateInfo = std.mem.zeroes(vk.VkPipelineViewportStateCreateInfo);
        viewport_state_create_info.sType = vk.VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO;
        viewport_state_create_info.viewportCount = 1;
        viewport_state_create_info.pViewports = &viewport;
        viewport_state_create_info.scissorCount = 1;
        viewport_state_create_info.pScissors = &scissor;

        var rasterizer: vk.VkPipelineRasterizationStateCreateInfo = std.mem.zeroes(vk.VkPipelineRasterizationStateCreateInfo);
        rasterizer.sType = vk.VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO;
        rasterizer.depthClampEnable = vk.VK_FALSE;
        rasterizer.rasterizerDiscardEnable = vk.VK_FALSE;
        rasterizer.polygonMode = vk.VK_POLYGON_MODE_FILL;
        rasterizer.lineWidth = 1.0;
        rasterizer.cullMode = vk.VK_CULL_MODE_BACK_BIT;
        rasterizer.frontFace = vk.VK_FRONT_FACE_CLOCKWISE;
        rasterizer.depthBiasEnable = vk.VK_FALSE;
        rasterizer.depthBiasConstantFactor = 0.0;
        rasterizer.depthBiasClamp = 0.0;
        rasterizer.depthBiasSlopeFactor = 0.0;

        var multisampling: vk.VkPipelineMultisampleStateCreateInfo = std.mem.zeroes(vk.VkPipelineMultisampleStateCreateInfo);
        multisampling.sType = vk.VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO;
        multisampling.sampleShadingEnable = vk.VK_FALSE;
        multisampling.rasterizationSamples = vk.VK_SAMPLE_COUNT_1_BIT;
        multisampling.minSampleShading = 1.0; // Optional
        multisampling.pSampleMask = null; // Optional
        multisampling.alphaToCoverageEnable = vk.VK_FALSE; // Optional
        multisampling.alphaToOneEnable = vk.VK_FALSE; // Optional

        var color_blend_attachment: vk.VkPipelineColorBlendAttachmentState = std.mem.zeroes(vk.VkPipelineColorBlendAttachmentState);
        color_blend_attachment.colorWriteMask = vk.VK_COLOR_COMPONENT_R_BIT | vk.VK_COLOR_COMPONENT_G_BIT | vk.VK_COLOR_COMPONENT_B_BIT | vk.VK_COLOR_COMPONENT_A_BIT;
        color_blend_attachment.blendEnable = vk.VK_TRUE;
        color_blend_attachment.srcColorBlendFactor = vk.VK_BLEND_FACTOR_ONE; // Optional
        color_blend_attachment.dstColorBlendFactor = vk.VK_BLEND_FACTOR_ZERO; // Optional
        color_blend_attachment.colorBlendOp = vk.VK_BLEND_OP_ADD; // Optional
        color_blend_attachment.srcAlphaBlendFactor = vk.VK_BLEND_FACTOR_ONE; // Optional
        color_blend_attachment.dstAlphaBlendFactor = vk.VK_BLEND_FACTOR_ZERO; // Optional
        color_blend_attachment.alphaBlendOp = vk.VK_BLEND_OP_ADD; // Optional

        var color_blending: vk.VkPipelineColorBlendStateCreateInfo = std.mem.zeroes(vk.VkPipelineColorBlendStateCreateInfo);
        color_blending.sType = vk.VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO;
        color_blending.logicOpEnable = vk.VK_FALSE;
        color_blending.logicOp = vk.VK_LOGIC_OP_COPY; // Optional
        color_blending.attachmentCount = 1;
        color_blending.pAttachments = &color_blend_attachment;
        color_blending.blendConstants[0] = 0.0; // Optional
        color_blending.blendConstants[1] = 0.0; // Optional
        color_blending.blendConstants[2] = 0.0; // Optional
        color_blending.blendConstants[3] = 0.0; // Optional
        //
        var pipeline_info: vk.VkGraphicsPipelineCreateInfo = std.mem.zeroes(vk.VkGraphicsPipelineCreateInfo);
        pipeline_info.sType = vk.VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO;
        pipeline_info.stageCount = 2;
        pipeline_info.pStages = &stage_infos;
        pipeline_info.pVertexInputState = &vertex_input_info;
        pipeline_info.pInputAssemblyState = &input_assembly_create_info;
        pipeline_info.pViewportState = &viewport_state_create_info;
        pipeline_info.pRasterizationState = &rasterizer;
        pipeline_info.pMultisampleState = &multisampling;
        pipeline_info.pDepthStencilState = null; // Optional
        pipeline_info.pColorBlendState = &color_blending;
        pipeline_info.pDynamicState = null;
        pipeline_info.layout = pipeline_layout;
        pipeline_info.renderPass = render_pass;
        pipeline_info.subpass = 0;
        pipeline_info.basePipelineHandle = null; // Optional
        pipeline_info.basePipelineIndex = -1; // Optional

        var pipeline: vk.VkPipeline = undefined;
        if (vk.vkCreateGraphicsPipelines(device, null, 1, &pipeline_info, null, &pipeline) != vk.VK_SUCCESS) {
            return error.CannotCreatePipeline;
        }

        return pipeline;
    }

    fn create_font_pipeline(arena: *Arena 
        , device: vk.VkDevice 
        , render_pass: vk.VkRenderPass 
        , swapchain: Swapchain
        , pipeline_layout: vk.VkPipelineLayout
        , p_opt: PipelineOptions) !vk.VkPipeline 
    {
        var scratch = lhmem.scratch_block();
        const vert_bytes = try read_file(&scratch, p_opt.vert_path);
        const vert_shader = create_shader_module(device, vert_bytes).?;
        defer vk.vkDestroyShaderModule(device, vert_shader, null);
        const frag_bytes = try read_file(&scratch, p_opt.frag_path);
        const frag_shader = create_shader_module(device, frag_bytes).?;
        defer vk.vkDestroyShaderModule(device, frag_shader, null);

        var vssci = std.mem.zeroes(vk.VkPipelineShaderStageCreateInfo);
        vssci.sType = vk.VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO;
        vssci.stage = vk.VK_SHADER_STAGE_VERTEX_BIT;
        vssci.module = vert_shader;
        vssci.pName = "main";

        var fssci = std.mem.zeroes(vk.VkPipelineShaderStageCreateInfo);
        fssci.sType = vk.VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO;
        fssci.stage = vk.VK_SHADER_STAGE_FRAGMENT_BIT;
        fssci.module = frag_shader;
        fssci.pName = "main";

        const stage_infos: [2]vk.VkPipelineShaderStageCreateInfo = .{ vssci, fssci };

        var vertex_input_info: vk.VkPipelineVertexInputStateCreateInfo = std.mem.zeroes(vk.VkPipelineVertexInputStateCreateInfo);
        vertex_input_info.sType = vk.VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO;

        var binding_description = font_v.get_binding_description(); 
        const attribute_description = font_v.get_attribute_description(arena);
        vertex_input_info.vertexBindingDescriptionCount = 1;
        vertex_input_info.vertexAttributeDescriptionCount = @intCast(attribute_description.len);
        vertex_input_info.pVertexBindingDescriptions = &binding_description;
        vertex_input_info.pVertexAttributeDescriptions = attribute_description.ptr;


        var input_assembly_create_info: vk.VkPipelineInputAssemblyStateCreateInfo =  undefined;
        input_assembly_create_info.sType = vk.VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO;
        input_assembly_create_info.pNext = null;
        input_assembly_create_info.flags = 0;
        input_assembly_create_info.topology = p_opt.topology;
        input_assembly_create_info.primitiveRestartEnable = vk.VK_FALSE;

        var viewport: vk.VkViewport = std.mem.zeroes(vk.VkViewport);
        viewport.x = 0.0;
        viewport.y = 0.0;
        viewport.width = @as(f32, @floatFromInt(swapchain.extent.width));
        viewport.height = @as(f32, @floatFromInt(swapchain.extent.height));
        viewport.minDepth = 0.0;
        viewport.maxDepth = 1.0;

        var scissor: vk.VkRect2D = std.mem.zeroes(vk.VkRect2D);
        var offset: vk.VkOffset2D = std.mem.zeroes(vk.VkOffset2D);
        offset.x = 0;
        offset.y = 0;
        scissor.offset = offset;
        scissor.extent = swapchain.extent;

        var viewport_state_create_info: vk.VkPipelineViewportStateCreateInfo = std.mem.zeroes(vk.VkPipelineViewportStateCreateInfo);
        viewport_state_create_info.sType = vk.VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO;
        viewport_state_create_info.viewportCount = 1;
        viewport_state_create_info.pViewports = &viewport;
        viewport_state_create_info.scissorCount = 1;
        viewport_state_create_info.pScissors = &scissor;

        var rasterizer: vk.VkPipelineRasterizationStateCreateInfo = std.mem.zeroes(vk.VkPipelineRasterizationStateCreateInfo);
        rasterizer.sType = vk.VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO;
        rasterizer.depthClampEnable = vk.VK_FALSE;
        rasterizer.rasterizerDiscardEnable = vk.VK_FALSE;
        rasterizer.polygonMode = vk.VK_POLYGON_MODE_FILL;
        rasterizer.lineWidth = 1.0;
        rasterizer.cullMode = vk.VK_CULL_MODE_BACK_BIT;
        rasterizer.frontFace = vk.VK_FRONT_FACE_CLOCKWISE;
        rasterizer.depthBiasEnable = vk.VK_FALSE;
        rasterizer.depthBiasConstantFactor = 0.0;
        rasterizer.depthBiasClamp = 0.0;
        rasterizer.depthBiasSlopeFactor = 0.0;

        var multisampling: vk.VkPipelineMultisampleStateCreateInfo = std.mem.zeroes(vk.VkPipelineMultisampleStateCreateInfo);
        multisampling.sType = vk.VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO;
        multisampling.sampleShadingEnable = vk.VK_FALSE;
        multisampling.rasterizationSamples = vk.VK_SAMPLE_COUNT_1_BIT;
        multisampling.minSampleShading = 1.0; // Optional
        multisampling.pSampleMask = null; // Optional
        multisampling.alphaToCoverageEnable = vk.VK_FALSE; // Optional
        multisampling.alphaToOneEnable = vk.VK_FALSE; // Optional

        var color_blend_attachment: vk.VkPipelineColorBlendAttachmentState = std.mem.zeroes(vk.VkPipelineColorBlendAttachmentState);
        color_blend_attachment.colorWriteMask = vk.VK_COLOR_COMPONENT_R_BIT | vk.VK_COLOR_COMPONENT_G_BIT | vk.VK_COLOR_COMPONENT_B_BIT | vk.VK_COLOR_COMPONENT_A_BIT;
        color_blend_attachment.blendEnable = vk.VK_TRUE;
        color_blend_attachment.srcColorBlendFactor = vk.VK_BLEND_FACTOR_ONE; // Optional
        color_blend_attachment.dstColorBlendFactor = vk.VK_BLEND_FACTOR_ZERO; // Optional
        color_blend_attachment.colorBlendOp = vk.VK_BLEND_OP_ADD; // Optional
        color_blend_attachment.srcAlphaBlendFactor = vk.VK_BLEND_FACTOR_ONE; // Optional
        color_blend_attachment.dstAlphaBlendFactor = vk.VK_BLEND_FACTOR_ZERO; // Optional
        color_blend_attachment.alphaBlendOp = vk.VK_BLEND_OP_ADD; // Optional

        var color_blending: vk.VkPipelineColorBlendStateCreateInfo = std.mem.zeroes(vk.VkPipelineColorBlendStateCreateInfo);
        color_blending.sType = vk.VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO;
        color_blending.logicOpEnable = vk.VK_FALSE;
        color_blending.logicOp = vk.VK_LOGIC_OP_COPY; // Optional
        color_blending.attachmentCount = 1;
        color_blending.pAttachments = &color_blend_attachment;
        color_blending.blendConstants[0] = 0.0; // Optional
        color_blending.blendConstants[1] = 0.0; // Optional
        color_blending.blendConstants[2] = 0.0; // Optional
        color_blending.blendConstants[3] = 0.0; // Optional
        //
        var pipeline_info: vk.VkGraphicsPipelineCreateInfo = std.mem.zeroes(vk.VkGraphicsPipelineCreateInfo);
        pipeline_info.sType = vk.VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO;
        pipeline_info.stageCount = 2;
        pipeline_info.pStages = &stage_infos;
        pipeline_info.pVertexInputState = &vertex_input_info;
        pipeline_info.pInputAssemblyState = &input_assembly_create_info;
        pipeline_info.pViewportState = &viewport_state_create_info;
        pipeline_info.pRasterizationState = &rasterizer;
        pipeline_info.pMultisampleState = &multisampling;
        pipeline_info.pDepthStencilState = null; // Optional
        pipeline_info.pColorBlendState = &color_blending;
        pipeline_info.pDynamicState = null;
        pipeline_info.layout = pipeline_layout;
        pipeline_info.renderPass = render_pass;
        pipeline_info.subpass = 0;
        pipeline_info.basePipelineHandle = null; // Optional
        pipeline_info.basePipelineIndex = -1; // Optional

        var pipeline: vk.VkPipeline = undefined;
        if (vk.vkCreateGraphicsPipelines(device, null, 1, &pipeline_info, null, &pipeline) != vk.VK_SUCCESS) {
            return error.CannotCreatePipeline;
        }

        return pipeline;
    }
};
