// adapters/zig/main.zig — the Zig backend's thin adapter for the C
// polyfills. Links libsh2poly.a directly and maps the sh2.* call-site
// convention to sh2poly_dispatch.
//
// Build: zig build-exe main.zig -I. -L../.. -lsh2poly -lc -O ReleaseSafe
// Run:   ./main   (reads adapters/battery.txt)
//
// The battery runner: reads battery.txt (TAB-separated fields, `\\` →
// backslash, `\n` → newline), sets up the deterministic stdin,
// dispatches every call, prints `== name` / `status=N`.
//
// Uses libc directly (extern declarations) for file I/O and output —
// the library is linked with -lc anyway, and this avoids depending on
// the std.Io API, which changed between Zig versions.
const std = @import("std");

extern fn sh2poly_init() void;
extern fn sh2poly_dispatch(argc: c_int, argv: [*c][*c]u8) c_int;

const FILE = opaque {};
extern fn fopen(path: [*c]const u8, mode: [*c]const u8) ?*FILE;
extern fn fclose(f: *FILE) c_int;
extern fn fgets(buf: [*c]u8, size: c_int, f: *FILE) [*c]u8;
extern fn fwrite(ptr: [*c]const u8, size: usize, nmemb: usize, f: *FILE) usize;
extern fn fileno(f: *FILE) c_int;
extern fn dup2(old: c_int, new: c_int) c_int;
extern var stdout: *FILE;

fn unescape(alloc: std.mem.Allocator, field: []const u8) ![]u8 {
    var out: std.array_list.Aligned(u8, null) = .empty;
    var i: usize = 0;
    while (i < field.len) {
        if (field[i] == '\\' and i + 1 < field.len) {
            switch (field[i + 1]) {
                '\\' => { try out.append(alloc, '\\'); i += 2; },
                'n' => { try out.append(alloc, '\n'); i += 2; },
                't' => { try out.append(alloc, '\t'); i += 2; },
                else => { try out.append(alloc, '\\'); i += 1; },
            }
        } else {
            try out.append(alloc, field[i]);
            i += 1;
        }
    }
    return out.toOwnedSlice(alloc);
}

fn cwrite(s: []const u8) void {
    _ = fwrite(s.ptr, 1, s.len, stdout);
}

pub fn main() !void {
    sh2poly_init();
    const alloc = std.heap.c_allocator;

    // deterministic stdin for the read/readarray calls
    const in_data = "alpha beta gamma\none\ntwo\nthree\n";
    {
        const f = fopen("/tmp/sh2poly_selftest_in.txt", "w") orelse return error.OpenFailed;
        _ = fwrite(in_data.ptr, 1, in_data.len, f);
        _ = fclose(f);
    }
    const in = fopen("/tmp/sh2poly_selftest_in.txt", "r") orelse return error.OpenFailed;
    _ = dup2(fileno(in), 0);

    const bat = fopen("adapters/battery.txt", "r") orelse return error.OpenFailed;
    var linebuf: [4096]u8 = undefined;
    while (fgets(&linebuf, linebuf.len, bat)) |line| {
        const raw = std.mem.sliceTo(line, 0);
        const trimmed = std.mem.trim(u8, raw, " \t\r\n");
        if (trimmed.len == 0 or trimmed[0] == '#') continue;
        var fields = std.mem.splitScalar(u8, trimmed, '\t');
        const name = fields.next() orelse continue;
        var args: std.array_list.Aligned([]u8, null) = .empty;
        defer {
            for (args.items) |a| alloc.free(a);
            args.deinit(alloc);
        }
        while (fields.next()) |f| {
            const uf = try unescape(alloc, f);
            const uz = try alloc.dupeZ(u8, uf);
            alloc.free(uf);
            try args.append(alloc, uz);
        }
        cwrite("== ");
        cwrite(name);
        cwrite("\n");
        var argv: std.array_list.Aligned([*c]u8, null) = .empty;
        defer argv.deinit(alloc);
        const namez = try alloc.dupeZ(u8, name);
        defer alloc.free(namez);
        try argv.append(alloc, @ptrCast(namez.ptr));
        for (args.items) |a| try argv.append(alloc, @ptrCast(a.ptr));
        try argv.append(alloc, null);
        const st = sh2poly_dispatch(@intCast(argv.items.len - 1), @ptrCast(argv.items.ptr));
        var stbuf: [32]u8 = undefined;
        const sts = try std.fmt.bufPrint(&stbuf, "status={d}\n", .{st});
        cwrite(sts);
    }
    _ = fclose(bat);
}
