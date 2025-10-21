const std = @import("std");
const tokenize = @import("tokenizer.zig").tokenize;
const Tokenizer = @import("tokenizer.zig").Tokenizer;
const Assembler = @import("assembler.zig").Assembler;

pub fn main() !void {
    var buf: [1024]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&buf);
    const stdout = &stdout_writer.interface;
    const argv = std.os.argv;
    const ra = try runargs.init(stdout, argv);
    if (ra.do_disasm) {
        try disasm(stdout, ra.filename);
    } else if (ra.do_assemble) {
        try assemble(stdout, ra.filename);
    }
    stdout.flush() catch |err| {
        std.debug.print("Error flushing stdout buffer: {any}\n", .{err});
    };
}

const runargs = struct {
    do_disasm: bool,
    do_assemble: bool,
    filename: []const u8,

    fn init(w: *std.Io.Writer, argv: [][*:0]u8) !runargs {
        const do_nothing = runargs{
            .do_disasm = false,
            .do_assemble = false,
            .filename = "",
        };
        if (argv.len < 2) {
            try w.print("Need args\n", .{});
            return do_nothing;
        }
        const arg1: [:0]const u8 = std.mem.span(argv[1]);
        if (std.mem.eql(u8, arg1, "-d")) {
            if (argv.len < 3) {
                try w.print("Disasm: need moar args\n", .{});
                return do_nothing;
            }
            return .{
                .do_disasm = true,
                .do_assemble = false,
                .filename = std.mem.span(argv[2]),
            };
        }
        return .{
            .do_disasm = false,
            .do_assemble = true,
            .filename = std.mem.span(argv[1]),
        };
    }
};

pub fn disasm(w: *std.Io.Writer, filename: []const u8) !void {
    try w.print("Disasm {s}. Not implemented.\n", .{filename});
}

pub fn assemble(w: *std.Io.Writer, filename: []const u8) !void {
    const data = try read_file(filename);
    defer std.heap.page_allocator.free(data);

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const tokenizer = Tokenizer.init(allocator, data);
    var assembler = try Assembler.init(allocator, tokenizer);
    const out = try assembler.do();
    try w.print("v3.0 hex words addressed\n", .{});
    for (out, 0..) |byte, i| {
        if (i % 16 == 0) {
            if (i > 0) {
                try w.print("\n", .{});
            }
            try w.print("{x:0>2}:", .{i});
        }
        try w.print(" {x:0>2}", .{byte});
    }
    try w.print("\n", .{});
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
