const std = @import("std");
const Allocator = std.mem.Allocator;
const HashMap = std.hash_map.HashMap;
const StringHashMap = std.hash_map.StringHashMap;
const Tokenizer = @import("tokenizer.zig").Tokenizer;
const Token = @import("tokenizer.zig").Token;
const Opcode = @import("isa.zig").Opcode;
const ISA = @import("isa.zig").ISA;
const ParamType = @import("isa.zig").ParamType;
const lookupReg = @import("isa.zig").lookupReg;

pub const AssemblerError = error{
    ImmediateTooLarge,
    ProgramTooLarge,
    UnknownLabel,
    UnknownOpcode,
    UnknownRegister,
};

pub const Assembler = struct {
    const LabelMap = StringHashMap(u8);

    alloc: Allocator,
    tokenizer: Tokenizer,
    intermediate_repr: [256]intermediateOp,
    output: [256]u8,
    output_idx: u16,
    label_map: LabelMap,
    isa: ISA,
    err: []const u8,

    pub fn init(allocator: Allocator, tokenizer: Tokenizer) !Assembler {
        return Assembler{
            .alloc = allocator,
            .tokenizer = tokenizer,
            .intermediate_repr = [_]intermediateOp{makeInterm()} ** 256,
            .output = [_]u8{0} ** 256,
            .output_idx = 0,
            .label_map = LabelMap.init(allocator),
            .isa = try ISA.init(allocator),
            .err = "",
        };
    }

    pub fn do(self: *Assembler) ![]const u8 {
        try self.firstPass();
        try self.secondPass();
        return &self.output;
    }

    fn firstPass(self: *Assembler) !void {
        var op_index: u8 = 0;
        var addr: u16 = 0;
        while (true) {
            const tok = try self.tokenizer.next();
            if (tok.is_eof()) {
                break;
            }
            if (tok.is_comment) {
                continue;
            }
            const opcode = &self.intermediate_repr[op_index];
            opcode.addr = @truncate(addr);
            if (tok.has_suffix(':')) {
                try self.label_map.put(tok.trim_label(), @truncate(addr));
                continue;
            }
            if (opcode.op.is_empty()) {
                const maybe_op = self.isa.lookupOp(tok.text);
                const op = maybe_op orelse {
                    return AssemblerError.UnknownOpcode;
                };
                if (addr > 255) {
                    return AssemblerError.ProgramTooLarge;
                }
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

    fn secondPass(self: *Assembler) !void {
        for (self.intermediate_repr) |interm| {
            switch (interm.op.param) {
                ParamType.is_register => try self.emitRegOpcode(interm),
                ParamType.is_immediate => try self.emitImmediateOpcode(interm),
                ParamType.is_ignored => self.emitOpcodeNoParam(interm),
                ParamType.is_label => try self.emitJumpOpcode(interm),
            }
        }
    }

    fn emitRegOpcode(self: *Assembler, interm: intermediateOp) !void {
        const reg = lookupReg(interm.param.text) orelse {
            return AssemblerError.UnknownRegister;
        };
        self.emit(interm.op, reg.code);
    }

    fn emitImmediateOpcode(self: *Assembler, interm: intermediateOp) !void {
        const token = interm.param.text;
        var immediate: u8 = undefined;
        if (std.ascii.startsWithIgnoreCase(token, "0x")) {
            immediate = try std.fmt.parseInt(u8, token, 16);
        } else if (std.ascii.startsWithIgnoreCase(token, "0o")) {
            immediate = try std.fmt.parseInt(u8, token, 8);
        } else {
            immediate = try std.fmt.parseInt(u8, token, 10);
        }
        const op_and_limit = self.xformLoadImmediate(interm.op, immediate);
        if (immediate > op_and_limit.limit) {
            return AssemblerError.ImmediateTooLarge;
        }
        self.emit(op_and_limit.opcode, immediate);
    }

    fn emitOpcodeNoParam(self: *Assembler, interm: intermediateOp) void {
        self.emit(interm.op, 0);
    }

    fn emitJumpOpcode(self: *Assembler, interm: intermediateOp) !void {
        const jump_addr = self.label_map.get(interm.param.text) orelse {
            return AssemblerError.UnknownLabel;
        };
        self.emitLI(jump_addr);
        self.emitSJF(interm.op.mnemonic);
        self.emitJMP(jump_addr);
    }

    fn xformLoadImmediate(self: *Assembler, in_op: Opcode, imm: u8) struct { opcode: Opcode, limit: u8 } {
        if (std.mem.eql(u8, in_op.mnemonic, "li")) {
            if (imm <= 7) {
                return .{ .opcode = in_op, .limit = 7 };
            }
            const new_op = self.isa.lookupOp("li1") orelse {
                unreachable;
            };
            return .{ .opcode = new_op, .limit = 15 };
        }
        if (std.mem.eql(u8, in_op.mnemonic, "li0") or std.mem.eql(u8, in_op.mnemonic, "li1")) {
            return .{ .opcode = in_op, .limit = 15 };
        }
        return .{ .opcode = in_op, .limit = 7 };
    }

    fn emitLI(self: *Assembler, jump_addr: u8) void {
        const upper_4_bits = (jump_addr & 0xf0) >> 4;
        const li_op_tmp = self.isa.lookupOp("li") orelse {
            unreachable;
        };
        const li_op_and_limit = self.xformLoadImmediate(li_op_tmp, upper_4_bits);
        self.emit(li_op_and_limit.opcode, upper_4_bits);
    }

    fn emitSJF(self: *Assembler, mnemonic: []const u8) void {
        var op: Opcode = undefined;
        var param: u8 = 0;
        if (std.mem.eql(u8, mnemonic, "jz")) {
            op = self.isa.lookupOp("sjf") orelse {
                unreachable;
            };
            param = 1;
        } else if (std.mem.eql(u8, mnemonic, "jnz")) {
            op = self.isa.lookupOp("sjfn") orelse {
                unreachable;
            };
            param = 1;
        } else if (std.mem.eql(u8, mnemonic, "jo")) {
            op = self.isa.lookupOp("sjf") orelse {
                unreachable;
            };
            param = 2;
        } else if (std.mem.eql(u8, mnemonic, "jno")) {
            op = self.isa.lookupOp("sjfn") orelse {
                unreachable;
            };
            param = 2;
        } else {
            op = self.isa.lookupOp("sjf") orelse {
                unreachable;
            };
            param = 0;
        }
        self.emit(op, param);
    }

    fn emitJMP(self: *Assembler, jump_addr: u8) void {
        const middle_bit = jump_addr & 0x08;
        const low_3_bits = jump_addr & 0x07;
        var jmp: Opcode = undefined;
        if (middle_bit == 0) {
            jmp = self.isa.lookupOp("jmplo") orelse {
                unreachable;
            };
        } else {
            jmp = self.isa.lookupOp("jmphi") orelse {
                unreachable;
            };
        }
        self.emit(jmp, low_3_bits);
    }

    pub fn emit(self: *Assembler, op: Opcode, param: u8) void {
        if (self.output_idx == 255) {
            return;
        }
        self.output[self.output_idx] = op.emit(param);
        self.output_idx += 1;
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
        .param = Token.init("", false),
    };
}
