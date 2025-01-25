const std = @import("std");
const Allocator = std.mem.Allocator;
const StringHashMap = std.hash_map.StringHashMap;

pub const ParamType = enum {
    is_register,
    is_immediate,
    is_ignored,
    is_label,
};

pub const ISA = struct {
    const OpcodeMap = StringHashMap(Opcode);

    alloc: Allocator,
    op_map: OpcodeMap,

    pub fn init(allocator: Allocator) !ISA {
        const op_map = try initOpMap(allocator, isa);
        return ISA{
            .alloc = allocator,
            .op_map = op_map,
        };
    }

    fn initOpMap(alloc: Allocator, opcodes: []const Opcode) !OpcodeMap {
        var m = OpcodeMap.init(alloc);
        for (opcodes) |opcode| {
            try m.put(opcode.mnemonic, opcode);
        }
        return m;
    }

    const isa: []const Opcode = &[_]Opcode{
        .{
            .code = 0x00,
            .mnemonic = "halt",
            .param = ParamType.is_ignored,
        },
        .{
            .code = 0x01,
            .mnemonic = "li",
            .param = ParamType.is_immediate,
        },
        .{
            .code = 0x02,
            .mnemonic = "ld",
        },
        .{
            .code = 0x03,
            .mnemonic = "st",
        },
        .{
            .code = 0x04,
            .mnemonic = "getpc",
        },
        .{
            .code = 0x05,
            .mnemonic = "getst",
        },
        .{
            .code = 0x06,
            .mnemonic = "setst",
        },
        .{
            .code = 0x07,
            .mnemonic = "shli",
            .param = ParamType.is_immediate,
        },
        .{
            .code = 0x08,
            .mnemonic = "shri",
            .param = ParamType.is_immediate,
        },
        .{
            .code = 0x09,
            .mnemonic = "getacc",
        },
        .{
            .code = 0x0a,
            .mnemonic = "setacc",
        },
        .{
            .code = 0x0b,
            .mnemonic = "swacc",
        },
        .{
            .code = 0x0c,
            .mnemonic = "or",
        },
        .{
            .code = 0x0d,
            .mnemonic = "and",
        },
        .{
            .code = 0x0e,
            .mnemonic = "xor",
        },
        .{
            .code = 0x0f,
            .mnemonic = "add",
        },
        .{
            .code = 0x10,
            .mnemonic = "sub",
        },
        .{
            .code = 0x11,
            .mnemonic = "inc",
            .param = ParamType.is_immediate,
        },
        .{
            .code = 0x12,
            .mnemonic = "dec",
            .param = ParamType.is_immediate,
        },
        .{
            .code = 0x13,
            .mnemonic = "UNK",
            .param = ParamType.is_immediate,
        },
        .{
            .code = 0x14,
            .mnemonic = "jz",
            .param = ParamType.is_label,
            .is_pseudo = true,
            .expansion_width = 3,
        },
        .{
            .code = 0x15,
            .mnemonic = "jnz",
            .param = ParamType.is_label,
            .is_pseudo = true,
            .expansion_width = 3,
        },
        .{
            .code = 0x16,
            .mnemonic = "jo",
            .param = ParamType.is_label,
            .is_pseudo = true,
            .expansion_width = 3,
        },
        .{
            .code = 0x17,
            .mnemonic = "jno",
            .param = ParamType.is_label,
            .is_pseudo = true,
            .expansion_width = 3,
        },
        .{
            .code = 0x18,
            .mnemonic = "jmp",
            .param = ParamType.is_label,
            .is_pseudo = true,
            .expansion_width = 3,
        },
        .{
            .code = 0x19,
            .mnemonic = "UNK",
            .param = ParamType.is_immediate,
        },
        .{
            .code = 0x1a,
            .mnemonic = "li0",
            .param = ParamType.is_immediate,
        },
        .{
            .code = 0x1b,
            .mnemonic = "li1",
            .param = ParamType.is_immediate,
        },
        .{
            .code = 0x1c,
            .mnemonic = "sjf",
            .param = ParamType.is_immediate,
        },
        .{
            .code = 0x1d,
            .mnemonic = "sjfn",
            .param = ParamType.is_immediate,
        },
        .{
            .code = 0x1e,
            .mnemonic = "jmplo",
            .param = ParamType.is_immediate,
        },
        .{
            .code = 0x1f,
            .mnemonic = "jmphi",
            .param = ParamType.is_immediate,
        },
    };

    const regs: []const Reg = [_]Reg{
        Reg.init("r0", 0),
        Reg.init("r1", 1),
        Reg.init("r2", 2),
        Reg.init("r3", 3),
        Reg.init("r4", 4),
        Reg.init("r5", 5),
        Reg.init("r6", 6),
        Reg.init("r7", 7),
    };
};

pub const Opcode = struct {
    code: u8, // binary value of the opcode extracted from the instruction
    mnemonic: []const u8, // the string representation of the instruction
    param: ParamType = ParamType.is_ignored,
    is_pseudo: bool = false, // this instruction is a pseudo, expanding to something else

    // number of instructions this expands to. Equals one for normal
    // instructions, and may be >=1 for pseudoinstructions. Will default to 1
    // if it's zero.
    expansion_width: u8 = 0,

    pub fn init() Opcode {
        return .{
            .code = 0,
            .mnemonic = "",
            .param = ParamType.is_ignored,
            .is_pseudo = false,
            .expansion_width = 0,
        };
    }

    pub fn is_empty(self: *const Opcode) bool {
        return self.mnemonic.len == 0;
    }

    pub fn emit(self: *const Opcode, param: u8) u8 {
        return (self.code << 3) | param;
    }
};

pub const Reg = struct {
    name: []const u8,
    code: u8,

    fn init(name: []const u8, code: u8) Reg {
        return .{
            .name = name,
            .code = code,
        };
    }
};
