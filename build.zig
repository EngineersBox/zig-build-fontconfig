const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const libxml2_enabled = b.option(bool, "enable-libxml2", "Build libxml2") orelse true;
    const freetype_enabled = b.option(bool, "enable-freetype", "Build freetype") orelse true;

    const lib = b.addStaticLibrary(.{
        .name = "fontconfig",
        .target = target,
        .optimize = optimize,
    });
    lib.linkLibC();
    if (target.result.os.tag != .windows) {
        lib.linkSystemLibrary("pthread");
    }
    if (freetype_enabled) {
        const freetype_dep = b.dependency("freetype", .{ .target = target, .optimize = optimize });
        lib.linkLibrary(freetype_dep.artifact("freetype"));
    }
    if (libxml2_enabled) {
        const libxml2_dep = b.dependency("libxml2", .{ .target = target, .optimize = optimize });
        lib.linkLibrary(libxml2_dep.artifact("xml2"));
    }

    lib.addIncludePath(b.path("upstream"));
    lib.addIncludePath(b.path("override/include"));

    var flags = std.ArrayList([]const u8).init(b.allocator);
    defer flags.deinit();
    try flags.appendSlice(&.{
        "-DHAVE_DIRENT_H",
        "-DHAVE_FCNTL_H",
        "-DHAVE_STDLIB_H",
        "-DHAVE_STRING_H",
        "-DHAVE_UNISTD_H",
        "-DHAVE_SYS_STATVFS_H",
        "-DHAVE_SYS_PARAM_H",
        "-DHAVE_SYS_MOUNT_H",

        "-DHAVE_LINK",
        "-DHAVE_MKSTEMP",
        "-DHAVE_MKOSTEMP",
        "-DHAVE__MKTEMP_S",
        "-DHAVE_MKDTEMP",
        "-DHAVE_GETOPT",
        "-DHAVE_GETOPT_LONG",
        //"-DHAVE_GETPROGNAME",
        //"-DHAVE_GETEXECNAME",
        "-DHAVE_RAND",
        "-DHAVE_RANDOM",
        "-DHAVE_LRAND48",
        //"-DHAVE_RANDOM_R",
        "-DHAVE_RAND_R",
        "-DHAVE_READLINK",
        "-DHAVE_FSTATVFS",
        "-DHAVE_FSTATFS",
        "-DHAVE_LSTAT",
        "-DHAVE_MMAP",
        "-DHAVE_VPRINTF",

        "-DHAVE_FT_GET_BDF_PROPERTY",
        "-DHAVE_FT_GET_PS_FONT_INFO",
        "-DHAVE_FT_HAS_PS_GLYPH_NAMES",
        "-DHAVE_FT_GET_X11_FONT_FORMAT",
        "-DHAVE_FT_DONE_MM_VAR",

        "-DHAVE_POSIX_FADVISE",

        //"-DHAVE_STRUCT_STATVFS_F_BASETYPE",
        // "-DHAVE_STRUCT_STATVFS_F_FSTYPENAME",
        // "-DHAVE_STRUCT_STATFS_F_FLAGS",
        // "-DHAVE_STRUCT_STATFS_F_FSTYPENAME",
        // "-DHAVE_STRUCT_DIRENT_D_TYPE",

        "-DFLEXIBLE_ARRAY_MEMBER",

        "-DHAVE_STDATOMIC_PRIMITIVES",

        "-DFC_GPERF_SIZE_T=size_t",

        // Default errors that fontconfig can't handle
        "-Wno-implicit-function-declaration",
        "-Wno-int-conversion",

        // https://gitlab.freedesktop.org/fontconfig/fontconfig/-/merge_requests/231
        "-fno-sanitize=undefined",
        "-fno-sanitize-trap=undefined",
    });
    switch (target.result.ptrBitWidth()) {
        32 => try flags.appendSlice(&.{
            "-DSIZEOF_VOID_P=4",
            "-DALIGNOF_VOID_P=4",
        }),

        64 => try flags.appendSlice(&.{
            "-DSIZEOF_VOID_P=8",
            "-DALIGNOF_VOID_P=8",
        }),

        else => @panic("unsupported arch"),
    }
    // This could be somewhat version specific, but it seems like
    // more of a pain than it is worth and these are old versions.
    // Let's just assume Unix-like systems have it available.
    //
    // Generic Linux: Unsure?
    // OpenBSD: https://man.openbsd.org/statvfs.3#HISTORY Since 4.4
    // FreeBSD: https://man.freebsd.org/cgi/man.cgi?statvfs#end Since 5.0
    // NetBSD: https://man.netbsd.org/statvfs.2#HISTORY Since 3.0
    const has_statvfs: bool = switch (target.result.os.tag) {
        .linux, .openbsd, .freebsd, .netbsd => true,
        else => false,
    };
    if (has_statvfs) {
        try flags.appendSlice(&.{
            "-DHAVE_SYS_VFS_H",
            "-DHAVE_SYS_STATFS_H",
        });
    }
    if (target.result.os.tag != .windows) {
        try flags.appendSlice(&.{
            "-DHAVE_PTHREAD",

            "-DFC_CACHEDIR=\"/var/cache/fontconfig\"",
            "-DFC_TEMPLATEDIR=\"/usr/share/fontconfig/conf.avail\"",
            "-DFONTCONFIG_PATH=\"/etc/fonts\"",
            "-DCONFIGDIR=\"/usr/local/fontconfig/conf.d\"",
            "-DFC_DEFAULT_FONTS=\"<dir>/usr/share/fonts</dir><dir>/usr/local/share/fonts</dir>\"",
        });
    }
    if (libxml2_enabled) {
        try flags.appendSlice(&.{
            "-DENABLE_LIBXML2",
        });
    }

    lib.addCSourceFiles(.{
        .files = srcs,
        .flags = flags.items,
    });

    inline for (headers) |header| {
        lib.installHeader(b.path("upstream/" ++ header), header);
    }

    b.installArtifact(lib);
}

const headers = &.{
    "fontconfig/fontconfig.h",
    "fontconfig/fcprivate.h",
    "fontconfig/fcfreetype.h",
};

const srcs = &.{
    "upstream/src/fcatomic.c",
    "upstream/src/fccache.c",
    "upstream/src/fccfg.c",
    "upstream/src/fccharset.c",
    "upstream/src/fccompat.c",
    "upstream/src/fcdbg.c",
    "upstream/src/fcdefault.c",
    "upstream/src/fcdir.c",
    "upstream/src/fcformat.c",
    "upstream/src/fcfreetype.c",
    "upstream/src/fcfs.c",
    "upstream/src/fcptrlist.c",
    "upstream/src/fchash.c",
    "upstream/src/fcinit.c",
    "upstream/src/fclang.c",
    "upstream/src/fclist.c",
    "upstream/src/fcmatch.c",
    "upstream/src/fcmatrix.c",
    "upstream/src/fcname.c",
    "upstream/src/fcobjs.c",
    "upstream/src/fcpat.c",
    "upstream/src/fcrange.c",
    "upstream/src/fcserialize.c",
    "upstream/src/fcstat.c",
    "upstream/src/fcstr.c",
    "upstream/src/fcweight.c",
    "upstream/src/fcxml.c",
    "upstream/src/ftglue.c",
};
