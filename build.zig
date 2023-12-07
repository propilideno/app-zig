const std = @import("std");

pub fn build(b: *std.build.Builder) !void {
    const target = b.standardTargetOptions(.{});
    // Standard release options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall.
    const optimize = b.standardOptimizeOption(.{});

    const facil_dep = b.dependency("facil.io", .{
        .target = target,
        .optimize = optimize,
    });

    // create a module to be used internally.
    var zap_module = b.createModule(.{
        .source_file = .{ .path = "lib/zap.zig" },
    });

    // register the module so it can be referenced
    // using the package manager.
    // TODO: How to automatically integrate the
    // facil.io dependency with the module?
    try b.modules.put(b.dupe("zap"), zap_module);

    const facil_lib = b.addStaticLibrary(.{
        .name = "facil.io",
        .target = target,
        .optimize = optimize,
    });

    facil_lib.linkLibrary(facil_dep.artifact("facil.io"));

    // we install the facil dependency, just to see what it's like
    // zig build with the default (install) step will install it
    facil_lib.installLibraryHeaders(facil_dep.artifact("facil.io"));
    const facil_install_step = b.addInstallArtifact(facil_lib, .{});
    b.getInstallStep().dependOn(&facil_install_step.step);

    const all_step = b.step("all", "build all apps");

    inline for ([_]struct {
        name: []const u8,
        src: []const u8,
    }{
        .{ .name = "app", .src = "src/main.zig" },
    }) |excfg| {
        const app_name = excfg.name;
        const app_src = excfg.src;
        const app_build_desc = try std.fmt.allocPrint(
            b.allocator,
            "build the {s} app",
            .{app_name},
        );
        const app_run_stepname = try std.fmt.allocPrint(
            b.allocator,
            "run-{s}",
            .{app_name},
        );
        const app_run_stepdesc = try std.fmt.allocPrint(
            b.allocator,
            "run the {s} app",
            .{app_name},
        );
        const app_run_step = b.step(app_run_stepname, app_run_stepdesc);
        const app_step = b.step(app_name, app_build_desc);

        var app = b.addExecutable(.{
            .name = app_name,
            .root_source_file = .{ .path = app_src },
            .target = target,
            .optimize = optimize,
        });

        app.linkLibrary(facil_dep.artifact("facil.io"));
        app.addModule("zap", zap_module);

        // const app_run = app.run();
        const app_run = b.addRunArtifact(app);
        app_run_step.dependOn(&app_run.step);

        // install the artifact - depending on the "app"
        const app_build_step = b.addInstallArtifact(app, .{});
        app_step.dependOn(&app_build_step.step);
        all_step.dependOn(&app_build_step.step);
    }
}
