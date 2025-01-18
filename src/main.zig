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
    const data = try read_file(filename);
    defer std.heap.page_allocator.free(data);
    try stdout.print("Input data: {s}\n", .{data});
}

pub fn read_file(filename: []const u8) ![]u8 {
    var file = try std.fs.cwd().openFile(filename, .{});
    defer file.close();

    // alternative way, involving a reader and explicitly using a GPA:
    //
    // var general_purpose_allocator = std.heap.GeneralPurposeAllocator(.{}){};
    // const gpa = general_purpose_allocator.allocator();
    // const data = try file.reader().readAllAlloc(
    //     gpa,
    //     1e6,
    // );
    // defer gpa.free(data);

    const data = try file.readToEndAlloc(std.heap.page_allocator, 1e6);
    return data;
}
