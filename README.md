A rewrite of VTISA assembler in Zig
===================================

This program is a rewrite of the VTISA assembler in Zig. The original was
written in Go and is available here[1]. The purpose of this rewrite is to learn
Zig, nothing else.

Run
---

`zig build run -- testdata/fib.s`

`zig build run -- -d testdata/outp.rom` (not implemented yet)

[1]: https://github.com/rtfb/logisim-tiny-cpu
