const std = @import("std");
const Allocator = std.mem.Allocator;
const HashMap = std.hash_map.HashMap;
const StringHashMap = std.hash_map.StringHashMap;
const Tokenizer = @import("tokenizer.zig").Tokenizer;
const Token = @import("tokenizer.zig").Token;
const Opcode = @import("isa.zig").Opcode;
const ISA = @import("isa.zig").ISA;
const ParamType = @import("isa.zig").ParamType;

pub const AssemblerError = error{
    ProgramTooLarge,
    UnknownOpcode,
};

pub const Assembler = struct {
    const LabelMap = StringHashMap(u8);

    alloc: Allocator,
    tokenizer: Tokenizer,
    intermediate_repr: [255]intermediateOp,
    label_map: LabelMap,
    isa: ISA,
    err: []const u8,

    pub fn init(allocator: Allocator, tokenizer: Tokenizer) !Assembler {
        return Assembler{
            .alloc = allocator,
            .tokenizer = tokenizer,
            .intermediate_repr = [_]intermediateOp{makeInterm()} ** 255,
            // .label_map = HashMap.init(allocator),
            .label_map = LabelMap.init(allocator),
            .isa = try ISA.init(allocator),
            .err = "",
        };
    }

    pub fn do(self: *Assembler) ![]const u8 {
        try self.firstPass();
        return try self.secondPass();
    }

    fn firstPass(self: *Assembler) !void {
        var op_index: u8 = 0;
        var addr: u16 = 0;
        while (true) {
            const tok = try self.tokenizer.next();
            if (tok.is_eof()) {
                break;
            }
            const opcode = &self.intermediate_repr[op_index];
            opcode.addr = @truncate(addr);
            if (tok.has_suffix(':')) {
                try self.label_map.put(tok.trim_label(), @truncate(addr));
                continue;
            }
            if (opcode.op.is_empty()) {
                const maybe_op = self.isa.op_map.get(tok.text);
                const op = maybe_op orelse {
                    return AssemblerError.UnknownOpcode;
                };
                // if (!self.isa.op_map.contains(tok.text)) {
                //     return AssemblerError.UnknownOpcode;
                // }
                if (addr > 255) {
                    return AssemblerError.ProgramTooLarge;
                }
                // const op = try self.isa.op_map.get(tok.text);
                opcode.op = op;
                if (op.param == ParamType.is_ignored) {
                    op_index += 1;
                    addr += 1;
                }
                continue;
            }
            opcode.param = tok;
            op_index += 1;
            var advance = opcode.op.expansion_width;
            if (advance == 0) {
                advance = 1;
            }
            addr += advance;
        }
    }

    fn secondPass(self: *Assembler) ![]const u8 {
        var output = [_]u8{0} ** 255;
        var out_index: u8 = 0;
        for (self.intermediate_repr) |interm| {
            output[out_index] = interm.op.emit(0);
            out_index += 1;
        }
        return &output;
    }
};

const intermediateOp = struct {
    addr: u8, // address of this instruction
    op: Opcode,
    param: Token,
};

fn makeInterm() intermediateOp {
    return intermediateOp{
        .addr = 0,
        .op = Opcode.init(),
        .param = Token.init(""),
    };
}
