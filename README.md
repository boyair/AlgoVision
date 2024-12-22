# AlgoVision
A framework written in zig used to make a visual represtantion of memory during a user given algorithm runtime.

# Why I made this?
I find algorithms and data structures fascinating and i wanted to have a way to see them in real time.

As my interest in zig became irresistible I decided my next project will be making just Algovison in zig.

Due to my previous expirience with [SDL2](https://www.libsdl.org/) building an [Icy tower "clone"](https://github.com/boyair/Icy_tower) it was an easy decision to just use it with a great [zig wrapper](https://github.com/ikskuh/SDL.zig) I found for it.

# Installation
- make sure you have [zig installed](https://ziglang.org/download) on your system (master is not supported)
- **if you are on linux** install the following packages on your system with your package manager:

 `SDL2`, `SDL2_image`, `SDL2_ttf` and `SDL2_mixer`
 
 
- create a new zig project and put this in your build.zig:
```zig
const std = @import("std");
const AlgoVision = @import("AlgoVision");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const exe = b.addExecutable(.{
        .name = "example",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    _ = b.dependency("AlgoVision", .{});
    AlgoVision.fullInstall(b, exe, "AlgoVision");

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}

```
and add this to your dependecies in build.zig.zon (the compiler will provide you the hash and than add it after the url):
```
        .AlgoVision = .{
            .url = "https://github.com/boyair/AlgoVision/archive/refs/heads/main.tar.gz",
        },

```

(or just install the example build from the latest tag)

- **if you are on windows** extract to your project the windeps container so that both folders are in the root of your project

# Running your algorithm:
- in order to learn how to use the framework to make a visual algorithm you can take a look at the documented examples or standart library (located in src/std)
- go to your root source file (usually main.zig) and import the algovision module like so:
 ```zig
 const AV = @import("AlgoVision");
 ```
- initiallize AlgoVision at the begining of your main function:
```zig
    try AV.init();
```
- call the start function after your algorithm was provided, for example:
```zig
pub fn main() !void {
    try AV.init();
    //
    //your algorithm here
    //
    try AV.start();
    }
```
or:
```zig
pub fn main() !void {
    try AV.init();
    defer AV.start() catch unreachable;
    //
    //your algorithm here
    //
    }
```
- go to you project directory root using your favorite terminal emulator
- type ```zig build run``` and watch the magic happen!
