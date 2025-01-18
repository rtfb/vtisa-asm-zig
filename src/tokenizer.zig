const std = @import("std");
const Allocator = std.mem.Allocator;

pub const Tokenizer = struct {
    alloc: Allocator,
    input: []const u8,
    pos: usize,

    pub fn init(allocator: Allocator, input: []const u8) Tokenizer {
        return Tokenizer{
            .alloc = allocator,
            .input = input,
            .pos = 0,
        };
    }

    pub fn next(self: *Tokenizer) ![]u8 {
        // const stdout = std.io.getStdOut().writer();
        var i = self.pos;
        while (i < self.input.len) {
            const b = self.input[i];
            // try stdout.print("input[{d}] = {c}\n", .{ i, b });
            if (b == ' ' or b == '\n' or b == '\t') {
                const tok_len = i - self.pos;
                const token = try self.alloc.alloc(u8, tok_len);
                @memcpy(token, self.input[self.pos..i]);
                self.pos = self.skip_space(i + 1);
                return token;
            }
            i += 1;
        }
        return "";
    }

    fn skip_space(self: *Tokenizer, start: usize) usize {
        var i = start;
        var b = self.input[i];
        while (b == ' ' or b == '\n' or b == '\t') {
            i += 1;
            b = self.input[i];
        }
        return i;
    }
};

test "Tokenizer.next() returns a token" {
    const input = "foo bar baz";
    var tokzer = Tokenizer.init(std.testing.allocator, input);
    const tok = try tokzer.next();
    try std.testing.expectEqualStrings("foo", tok);
    std.testing.allocator.free(tok);
}

test "Tokenizer.next() returns empty token on empty input" {
    const input = "";
    var tokzer = Tokenizer.init(std.testing.allocator, input);
    const tok = try tokzer.next();
    try std.testing.expectEqualStrings("", tok);
}

test "Tokenizer loop" {
    const input = "foo bar baz";
    var tokzer = Tokenizer.init(std.testing.allocator, input);
    const want_tokens: [3][]const u8 = .{
        "foo", "bar", "baz",
    };
    var i: u32 = 0;
    while (true) {
        const tok = try tokzer.next();
        if (tok.len == 0) {
            break;
        }
        try std.testing.expectEqualStrings(want_tokens[i], tok);
        std.testing.allocator.free(tok);
        i += 1;
    }
}

test "Tokenizer loop with one token" {
    const input = "/.zig-cache";
    var tokzer = Tokenizer.init(std.testing.allocator, input);
    const want_tokens: [1][]const u8 = .{
        "/.zig-cache",
    };
    var i: u32 = 0;
    while (true) {
        const tok = try tokzer.next();
        if (tok.len == 0) {
            break;
        }
        try std.testing.expectEqualStrings(want_tokens[i], tok);
        std.testing.allocator.free(tok);
        i += 1;
    }
}

test "Tokenizer skip_space" {
    const input = "foo   bar \t\n    baz";
    var tokzer = Tokenizer.init(std.testing.allocator, input);
    const want_tokens: [3][]const u8 = .{
        "foo", "bar", "baz",
    };
    var i: u32 = 0;
    while (true) {
        const tok = try tokzer.next();
        if (tok.len == 0) {
            break;
        }
        try std.testing.expectEqualStrings(want_tokens[i], tok);
        std.testing.allocator.free(tok);
        i += 1;
    }
}
