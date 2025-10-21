/*
 * Compute Fibonacci sequence. Fill RAM with 1, 1, 2, 3, etc, until the sum
 * overflows 8 bits.
 */

LI 1
GETACC r7     // fib(1)=1
GETACC r6     // fib(2)=1

LI 0
ST r6         // store [r6] to [0]
INC 1
ST r7         // store [r7] to [1]
INC 1
GETACC r5     // index to write result to (r5 = 2)

loop:
    SETACC r7
    GETACC r2 // preserve r7 in r2 temporarily
    SETACC r6
    ADD r7
    GETACC r7 // r7 now contains the larger Fib number
    SETACC r2
    GETACC r6 // r6 now contains the smaller Fib number

    jo exit

    SETACC r5 // acc = index
    ST r7     // store the latest Fib number in mem
    INC 1
    GETACC r5

    jmp loop

exit:
HALT
