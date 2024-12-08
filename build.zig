const std = @import("std");
const Sdk = @import("SDL");
const builtin = @import("builtin");

var asset_path: std.Build.LazyPath = undefined;
var mixerdll: std.Build.LazyPath = undefined;
var imagedll: std.Build.LazyPath = undefined;
var sdk: *Sdk = undefined;
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    sdk = Sdk.init(b, null, null);
    asset_path = b.path("assets/");
    b.installDirectory(.{ .source_dir = asset_path, .install_dir = .{ .bin = {} }, .install_subdir = "./" });

    const lib = b.addStaticLibrary(.{
        .name = "AlgoVision",
        .root_source_file = b.path("src/app.zig"),
        .target = target,
        .optimize = optimize,
    });
    asset_path = b.path("assets/");
    lib.root_module.addImport("SDL", sdk.getWrapperModule());
    b.installArtifact(lib);
    mixerdll = b.path("windows/bin/SDL2_mixer.dll");
    imagedll = b.path("windows/bin/SDL2_image.dll");
    if (target.result.os.tag == .windows) {
        b.installBinFile("windows/bin/SDL2_mixer.dll", "./SDL2_mixer.dll");
        b.installBinFile("windows/bin/SDL2_image.dll", "./SDL2_image.dll");
        linkWindows(lib);
    }
}

fn getWinDLLs(b: *std.Build) void {
    b.installBinFile("windows/bin/SDL2_mixer.dll", "./SDL2_mixer.dll");
    b.installBinFile("windows/bin/SDL2_image.dll", "./SDL2_image.dll");
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
    exe.subsystem = .Windows;
}
pub fn getAssets(b: *std.Build) void {
    b.installDirectory(.{
        .source_dir = asset_path,
        .install_dir = .{ .bin = {} },
        .install_subdir = "./",
    });
}

pub fn linkSDL(exe: *std.Build.Step.Compile) void {
    sdk.link(exe, .dynamic, .SDL2); // link SDL2 as a static library
    sdk.link(exe, .dynamic, .SDL2_ttf); // link SDL2_ttf as a static library
    exe.linkSystemLibrary("SDL2_image");
    exe.linkSystemLibrary("SDL2_mixer");
    exe.linkLibC();
    //  if (target.result.os.tag == .windows) {
    //      b.installBinFile("windows/bin/SDL2_mixer.dll", "./SDL2_mixer.dll");
    //      b.installBinFile("windows/bin/SDL2_image.dll", "./SDL2_image.dll");
    //      exe.subsystem = .Windows;
    //      linkWindows(exe);
    //  }
}
