const std = @import("std");

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();
    const w = "world";
    try stdout.print("Hello, {s}\n", .{w});
    const argv = std.os.argv;
    if (argv.len < 2) {
        try stdout.print("Need args\n", .{});
        std.process.exit(0);
    }
    const arg1: [:0]const u8 = std.mem.span(argv[1]);
    if (std.mem.eql(u8, arg1, "-d")) {
        if (argv.len < 3) {
            try stdout.print("Disasm: need moar args\n", .{});
            std.process.exit(0);
        }
        const filename: [:0]const u8 = std.mem.span(argv[2]);
        try disasm(filename);
    } else {
        const filename: [:0]const u8 = std.mem.span(argv[1]);
        try assemble(filename);
    }
}

pub fn disasm(filename: []const u8) !void {
    const stdout = std.io.getStdOut().writer();
    try stdout.print("Disasm {s}\n", .{filename});
}

pub fn assemble(filename: []const u8) !void {
    const stdout = std.io.getStdOut().writer();
    try stdout.print("Asm {s}\n", .{filename});
}
