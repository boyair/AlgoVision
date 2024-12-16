const std = @import("std");
pub const Sdk = @import("SDL");
var asset_path: std.fs.Dir = undefined;
var module: *std.Build.Module = undefined;
var is_lib = false;
var lib_build: *std.Build = undefined;
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    module = b.addModule("AlgoVision", .{
        .root_source_file = b.path("src/app.zig"),
        .target = target,
        .optimize = optimize,
    });
    asset_path = std.fs.openDirAbsolute(std.fs.path.join(b.allocator, &.{ b.build_root.path.?, "assets/" }) catch {
        @panic("failed to allocate memory for asset path");
    }, .{ .iterate = true }) catch {
        @panic("unable to open asset directory");
    };
    if (!is_lib) {
        const exe = b.addExecutable(.{
            .name = "example",
            .root_source_file = b.path("example/example.zig"),
            .target = target,
            .optimize = optimize,
        });
        const mod = getModule(b);
        exe.root_module.addImport("AlgoVision", mod);
        linkSDL(b, exe);
        installAssets(b) catch {
            @panic("failed to install assets");
        };
        //const install_artifact = b.addInstallArtifact(exe, .{});
        b.installArtifact(exe);
        const run_step = b.step("run-example", "runs the example program");
        const run_example = b.addRunArtifact(exe);
        run_example.step.dependOn(b.getInstallStep());
        run_step.dependOn(&run_example.step);
    }
}
pub fn fullInstall(b: *std.Build, exe: *std.Build.Step.Compile, module_name: []const u8) void {
    is_lib = true;
    _ = b.dependency("AlgoVision", .{});
    const mod = getModule(b);
    exe.root_module.addImport(module_name, mod);
    linkSDL(b, exe);
    installAssets(b) catch {
        @panic("failed to install assets");
    };
}

pub fn installAssets(b: *std.Build) !void {
    const bin_path = try std.fs.path.join(b.allocator, &.{ b.install_path, "bin" });
    const bin_directory: std.fs.Dir = std.fs.openDirAbsolute(bin_path, .{}) catch blk: {
        var dir = try std.fs.openDirAbsolute(b.build_root.path.?, .{});
        try dir.makePath("zig-out/bin"); //if path already exists this code wont be reached.
        break :blk try std.fs.openDirAbsolute(bin_path, .{});
    };
    var walker = try asset_path.walk(b.allocator);
    defer walker.deinit();
    while (try walker.next()) |entry| {
        switch (entry.kind) {
            .directory => {
                // Create subdirectory in destination
                try bin_directory.makePath(entry.path);
            },
            .file => {
                // Copy file from source to destination
                try asset_path.copyFile(entry.path, bin_directory, entry.path, .{});
            },
            else => continue,
        }
    }
}

pub fn getModule(b: *std.Build) *std.Build.Module {
    const sdk = Sdk.init(b, null, null);
    module.addImport("SDL", sdk.getWrapperModule());
    module.addIncludePath(b.path("windows/include/"));
    return module;
}

pub fn linkSDL(b: *std.Build, exe: *std.Build.Step.Compile) void {
    const target_os = exe.rootModuleTarget().os.tag;
    const sdk = Sdk.init(b, null, null);
    exe.root_module.addImport("SDL", sdk.getWrapperModule());
    if (target_os == .windows) {
        b.installBinFile("windows/bin/SDL2_mixer.dll", "./SDL2_mixer.dll");
        b.installBinFile("windows/bin/SDL2_image.dll", "./SDL2_image.dll");
        exe.subsystem = .Windows;

        //exe.root_module.addImport("SDL", )
        sdk.link(exe, .dynamic, .SDL2); // link SDL2 as a static library
        sdk.link(exe, .dynamic, .SDL2_ttf); // link SDL2_ttf as a static library
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
        exe.linkLibC();
    } else {
        sdk.link(exe, .static, .SDL2); // link SDL2 as a static library
        sdk.link(exe, .static, .SDL2_ttf); // link SDL2_ttf as a static library
        exe.linkSystemLibrary("SDL2_image");
        exe.linkSystemLibrary("SDL2_mixer");
    }
}
