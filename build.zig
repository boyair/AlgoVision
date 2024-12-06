const std = @import("std");
const Sdk = @import("SDL");
const builtin = @import("builtin");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});

    const optimize = b.standardOptimizeOption(.{});

    const sdk = Sdk.init(b, null, null);
    const asset_path = b.path("assets/");
    b.installDirectory(.{ .source_dir = asset_path, .install_dir = .{ .bin = {} }, .install_subdir = "./" });

    const exe = b.addExecutable(.{
        .name = "visualiser",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    const lib = b.addStaticLibrary(.{
        .name = "AlgoVision",
        .root_source_file = b.path("src/app.zig"),
        .target = target,
        .optimize = optimize,
    });
    b.installArtifact(lib);

    lib.root_module.addImport("SDL", sdk.getWrapperModule());
    exe.root_module.addImport("AlgoVision", &lib.root_module);
    sdk.link(exe, .dynamic, .SDL2); // link SDL2 as a static library
    sdk.link(exe, .dynamic, .SDL2_ttf); // link SDL2_ttf as a static library
    exe.linkSystemLibrary("SDL2_image");
    exe.linkSystemLibrary("SDL2_mixer");
    if (target.result.os.tag == .windows) {
        b.installBinFile("windows/bin/SDL2_mixer.dll", "./SDL2_mixer.dll");
        b.installBinFile("windows/bin/SDL2_image.dll", "./SDL2_image.dll");
        exe.subsystem = .Windows;
        linkWindows(exe);
    }
    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);

    run_cmd.step.dependOn(b.getInstallStep());

    // This allows the user to pass arguments to the application in the build
    // command itself, like this: `zig build run -- arg1 arg2 etc`
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    // This creates a build step. It will be visible in the `zig build --help` menu,
    // and can be selected like this: `zig build run`
    // This will evaluate the `run` step rather than the default, which is "install".
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    // Creates a step for unit testing. This only builds the test executable
    // but does not run it.
    const lib_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);

    const exe_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    if (exe_unit_tests.installed_path) |path| {
        b.installDirectory(.{ .source_dir = asset_path, .install_dir = .{ .prefix = {} }, .install_subdir = path });
    }

    exe_unit_tests.root_module.addImport("SDL", sdk.getWrapperModule());
    sdk.link(exe_unit_tests, .static, .SDL2); // link SDL2 as a static library
    sdk.link(exe_unit_tests, .static, .SDL2_ttf); // link SDL2_ttf as a static library
    exe_unit_tests.linkSystemLibrary("SDL2_image");
    exe_unit_tests.linkSystemLibrary("SDL2_mixer");
    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    // Similar to creating the run step earlier, this exposes a `test` step to
    // the `zig build --help` menu, providing a way for the user to request
    // running the unit tests.
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);
    test_step.dependOn(&run_exe_unit_tests.step);
}

fn linkWindows(exe: *std.Build.Step.Compile) void {
    exe.linkSystemLibrary("mingw32");
    exe.linkSystemLibrary("SDL2main");
    exe.linkSystemLibrary("SDL2");
    exe.linkSystemLibrary("SDL2_ttf");
    exe.linkSystemLibrary("SDL2_mixer");
    exe.linkSystemLibrary("SDL2_image");
    exe.linkSystemLibrary("user32");
    exe.linkSystemLibrary("gdi32");
    exe.linkSystemLibrary("winmm");
    exe.linkSystemLibrary("imm32");
    exe.linkSystemLibrary("ole32");
    exe.linkSystemLibrary("oleaut32");
    exe.linkSystemLibrary("version");
    exe.linkSystemLibrary("uuid");
    exe.linkSystemLibrary("shell32");
    exe.linkSystemLibrary("setupapi");
}
