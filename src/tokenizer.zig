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

    pub fn next(self: *Tokenizer) !Token {
        // const stdout = std.io.getStdOut().writer();
        var i = self.skip_space(self.pos);
        while (i < self.input.len) {
            const b = self.input[i];
            // try stdout.print("input[{d}] = {c}\n", .{ i, b });
            if (b == ' ' or b == '\n' or b == '\t') {
                return self.make_token(i, false);
            }
            if (b == '/') {
                const comment = self.try_comment(i);
                if (comment.was_found) {
                    return self.make_token(comment.end, true);
                }
            }
            i += 1;
        }
        if (i > self.pos) {
            return self.make_token(i, false);
        }
        return Token.init("", false);
    }

    fn make_token(self: *Tokenizer, to_pos: usize, is_comment: bool) !Token {
        const tok_len = to_pos - self.pos;
        const token = try self.alloc.alloc(u8, tok_len);
        @memcpy(token, self.input[self.pos..to_pos]);
        self.pos = to_pos;
        return Token.init(token, is_comment);
    }

    fn try_comment(self: *Tokenizer, start: usize) struct { was_found: bool, end: usize } {
        if (start >= self.input.len) {
            return .{ .was_found = false, .end = start };
        }
        var i = start + 1;
        if (i >= self.input.len) {
            return .{ .was_found = false, .end = start };
        }
        var b = self.input[i];
        if (b == '*') {
            const multiline = self.try_multiline(i);
            if (multiline.was_found) {
                return .{ .was_found = true, .end = multiline.end };
            }
        }
        if (b != '/') {
            return .{ .was_found = false, .end = start };
        }
        while (i < self.input.len and b != '\n') {
            b = self.input[i];
            i += 1;
        }
        return .{ .was_found = true, .end = i };
    }

    fn try_multiline(self: *Tokenizer, start: usize) struct { was_found: bool, end: usize } {
        if (start >= self.input.len) {
            return .{ .was_found = false, .end = start };
        }
        var i = start;
        while (i < self.input.len - 2) {
            i += 1;
            if (self.input[i] == '*' and self.input[i + 1] == '/') {
                return .{ .was_found = true, .end = i + 2 };
            }
        }
        return .{ .was_found = false, .end = start };
    }

    fn skip_space(self: *Tokenizer, start: usize) usize {
        if (self.input.len == 0) {
            return start;
        }
        if (start >= self.input.len - 1) {
            return start;
        }
        var i = start;
        var b = self.input[i];
        while (b == ' ' or b == '\n' or b == '\t') {
            i += 1;
            b = self.input[i];
        }
        self.pos = i;
        return i;
    }
};

pub const Token = struct {
    text: []const u8,
    is_comment: bool,
    // position: pos, // TODO

    pub fn init(text: []const u8, is_comment: bool) Token {
        return Token{
            .text = text,
            .is_comment = is_comment,
        };
    }

    pub fn is_eof(self: *const Token) bool {
        return self.text.len == 0;
    }

    pub fn has_suffix(self: *const Token, ch: u8) bool {
        return self.text[self.text.len - 1] == ch;
    }

    pub fn trim_label(self: *const Token) []const u8 {
        return self.text[0 .. self.text.len - 1];
    }
};

test "Tokenizer.next() returns a token" {
    const input = "foo bar baz";
    var tokzer = Tokenizer.init(std.testing.allocator, input);
    const tok = try tokzer.next();
    try std.testing.expectEqualStrings("foo", tok.text);
    std.testing.allocator.free(tok.text);
}

test "Tokenizer.next() leading spaces" {
    const input = "  \t\n  foo bar baz";
    var tokzer = Tokenizer.init(std.testing.allocator, input);
    const tok = try tokzer.next();
    try std.testing.expectEqualStrings("foo", tok.text);
    std.testing.allocator.free(tok.text);
}

test "Tokenizer.next() returns empty token on empty input" {
    const input = "";
    var tokzer = Tokenizer.init(std.testing.allocator, input);
    const tok = try tokzer.next();
    try std.testing.expectEqualStrings("", tok.text);
}

test "Tokenizer loop" {
    const input = "foo bar / baz";
    var tokzer = Tokenizer.init(std.testing.allocator, input);
    const want_tokens: [4][]const u8 = .{
        "foo", "bar", "/", "baz",
    };
    var i: u32 = 0;
    while (true) {
        const tok = try tokzer.next();
        if (tok.is_eof()) {
            break;
        }
        try std.testing.expectEqualStrings(want_tokens[i], tok.text);
        std.testing.allocator.free(tok.text);
        i += 1;
    }
}

test "Tokenizer loop with newline at the end" {
    const input = "foo bar / baz\n";
    var tokzer = Tokenizer.init(std.testing.allocator, input);
    const want_tokens: [4][]const u8 = .{
        "foo", "bar", "/", "baz",
    };
    var i: u32 = 0;
    while (true) {
        const tok = try tokzer.next();
        if (tok.is_eof()) {
            break;
        }
        try std.testing.expectEqualStrings(want_tokens[i], tok.text);
        std.testing.allocator.free(tok.text);
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
    var ntokens: u32 = 0;
    while (true) {
        const tok = try tokzer.next();
        if (tok.is_eof()) {
            break;
        }
        ntokens += 1;
        try std.testing.expectEqualStrings(want_tokens[i], tok.text);
        std.testing.allocator.free(tok.text);
        i += 1;
    }
    try std.testing.expectEqual(1, ntokens);
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
        if (tok.is_eof()) {
            break;
        }
        try std.testing.expectEqualStrings(want_tokens[i], tok.text);
        std.testing.allocator.free(tok.text);
        i += 1;
    }
}

test "zig-style comments" {
    const input = "  foo, bar;  // this is a comment";
    var tokzer = Tokenizer.init(std.testing.allocator, input);
    const want_tokens: [3][]const u8 = .{
        "foo,", "bar;", "// this is a comment",
    };
    var i: u32 = 0;
    var ntokens: u32 = 0;
    while (true) {
        const tok = try tokzer.next();
        if (tok.is_eof()) {
            break;
        }
        ntokens += 1;
        try std.testing.expectEqualStrings(want_tokens[i], tok.text);
        std.testing.allocator.free(tok.text);
        i += 1;
    }
    try std.testing.expectEqual(3, ntokens);
}

test "multiline comments" {
    const input =
        \\/*
        \\ * this is a multiline comment
        \\ */
        \\foo
    ;
    var tokzer = Tokenizer.init(std.testing.allocator, input);
    const want_tokens: [2][]const u8 = .{
        "/*\n * this is a multiline comment\n */",
        "foo",
    };
    var i: u32 = 0;
    var ntokens: u32 = 0;
    while (true) {
        const tok = try tokzer.next();
        if (tok.is_eof()) {
            break;
        }
        ntokens += 1;
        try std.testing.expectEqualStrings(want_tokens[i], tok.text);
        std.testing.allocator.free(tok.text);
        i += 1;
    }
    try std.testing.expectEqual(2, ntokens);
}

test "self-closing multiline comment" {
    const input = "/**/";
    var tokzer = Tokenizer.init(std.testing.allocator, input);
    const tok = try tokzer.next();
    try std.testing.expectEqualStrings("/**/", tok.text);
    std.testing.allocator.free(tok.text);
}
