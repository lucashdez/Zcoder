// const std = @import("std");
// pub fn build(b: *std.Build) void {
//     const target = b.standardTargetOptions(.{});
//     const optimize = b.standardOptimizeOption(.{});
//     const mod = b.addModule("zcoder", .{
//         .root_source_file = b.path("src/main.zig"),
//         .target = target,
//     });
//     const exe = b.addExecutable(.{
//         .name = "zcoder",
//         .root_module = b.createModule(.{
//             .root_source_file = b.path("src/main.zig"),
//             .target = target,
//             .optimize = optimize,
//
//             .imports = &.{
//                 .{ .name = "zcoder", .module = mod },
//             },
//         }),
//     });
//
//
//     exe.linkLibC();
//     exe.addLibraryPath(b.path("lib"));
//     exe.addIncludePath(b.path("include"));
//     if (@import("builtin").os.tag == .windows) {
//         exe.addLibraryPath(b.path("lib/x64"));
//         exe.linkSystemLibrary("vulkan-1");
//     } else {
//         exe.linkSystemLibrary("vulkan");
//         exe.linkSystemLibrary("wayland-client");
//         exe.addObjectFile(b.path("lib/xdg-shell-code.o"));
//     }
//
//     b.installArtifact(exe);
//     const run_cmd = b.addRunArtifact(exe);
//     run_cmd.step.dependOn(b.getInstallStep());
//
//     if (b.args) |args| {
//         run_cmd.addArgs(args);
//     }
//
//     const run_step = b.step("run", "Run the app");
//     run_step.dependOn(&run_cmd.step);
//
//     const exe_unit_tests = b.addTest(.{ .name = "zcoder test", .root_module = b.addModule("src/main.zig", .{}) });
//
//     const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);
//
//     // Similar to creating the run step earlier, this exposes a `test` step to
//     // the `zig build --help` menu, providing a way for the user to request
//     // running the unit tests.
//     const test_step = b.step("test", "Run unit tests");
//     test_step.dependOn(&run_exe_unit_tests.step);
// }
//

const std = @import("std");
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const mod = b.addModule("zcoder", .{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
    });

    const exe = b.addExecutable(.{
        .name = "zcoder",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),

            .target = target,
            .optimize = optimize,

            .imports = &.{
                .{ .name = "minizig", .module = mod },
            },
        }),
    });

    exe.linkLibC();
    exe.addLibraryPath(b.path("lib"));
    exe.addIncludePath(b.path("include"));
    if (@import("builtin").os.tag == .windows) {
        exe.addLibraryPath(b.path("lib/x64"));
        exe.linkSystemLibrary("vulkan-1");
    } else {
        exe.linkSystemLibrary("vulkan");
        exe.linkSystemLibrary("wayland-client");
        exe.addObjectFile(b.path("lib/xdg-shell-code.o"));
    }

    b.installArtifact(exe);
    const run_step = b.step("run", "Run the app");
    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const mod_tests = b.addTest(.{
        .root_module = mod,
    });

    const run_mod_tests = b.addRunArtifact(mod_tests);

    const exe_tests = b.addTest(.{
        .root_module = exe.root_module,
    });

    const run_exe_tests = b.addRunArtifact(exe_tests);

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_mod_tests.step);
    test_step.dependOn(&run_exe_tests.step);
}
