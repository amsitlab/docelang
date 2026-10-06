const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const docesyntax = b.createModule(.{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const docesyntax_lib = b.addLibrary(.{
        .name = "docesyntax",
        .linkage = .static,
        .root_module = docesyntax,
    });
    b.installArtifact(docesyntax_lib);

    const tests = b.createModule(.{
        .root_source_file = b.path("test/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    tests.addImport("docesyntax", docesyntax);

    // 1. Buat unit test executable dari source file
    const unit_tests = b.addTest(.{
        .name = "docesyntax-tests",
        .root_module = tests,
        .use_llvm = true,
    });

    const run_unit_tests = b.addRunArtifact(unit_tests);

    // 2. Buat "test" step agar bisa dipanggil lewat: zig build test
    const test_step = b.step("test", "Run all unit test");
    test_step.dependOn(&run_unit_tests.step);

    const raw = b.addSystemCommand(&.{ b.graph.zig_exe, "test", "-fllvm", "--dep", "docesyntax" });
    raw.addPrefixedFileArg("-Mroot=", b.path("tests/root.zig"));
    raw.addPrefixedFileArg("-Mdocesyntax=", b.path("src/root.zig"));
    raw.setCwd(b.path("."));
    raw.has_side_effects = true;
    const raw_step = b.step("test:raw", "Test with raw output");
    raw_step.dependOn(&raw.step);
    // Step untuk membuat dokumentasi
    const docs_step = b.step("docs", "Generate doc API");

    // Ambil hasil emit dokumentasi dari compiler
    const docs_install = b.addInstallDirectory(.{
        .source_dir = docesyntax_lib.getEmittedDocs(),
        .install_dir = .prefix,
        .install_subdir = "docs",
    });

    docs_step.dependOn(&docs_install.step);
    const all_step = b.step("all","Run all steps");
    all_step.dependOn(test_step);
    all_step.dependOn(docs_step);
}
