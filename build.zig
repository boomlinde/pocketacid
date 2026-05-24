const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "pocketacid",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    exe.linkLibC();
    exe.linkSystemLibrary("sdl2");
    exe.addIncludePath(b.path("src/clibs/include"));
    exe.addCSourceFile(.{
        .file = b.path("src/clibs/stbi.c"),
        .flags = &.{"-O3"},
    });
    if (target.result.os.tag == .windows) {
        exe.addIncludePath(b.path("prereqs/SDL2/include"));
        exe.addLibraryPath(b.path("prereqs/SDL2/lib/x64"));
        exe.subsystem = .Windows;
    }
    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| run_cmd.addArgs(args);

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
