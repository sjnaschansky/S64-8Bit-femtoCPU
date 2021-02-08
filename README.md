# S64-8Bit-femtoCPU
Around 2009-2010, I came across an interesting article.
It was "MCPU - A Minimal 8Bit CPU in a 32 Macrocell CPLD".
The author described a successful attempt to fit a simple 8 bit CPU into a 32 macrocell CPLD.
I liked this project and decided to develop my own 8 bit little microprocessor.
I developed S64. The name "S64" means "S"mall CPU for 64 macrocell CPLD.
The CPU supports 6 instructions: ADD, SUB, NOR, LDA, STA, JCC.
Program counter PC is 8 bits wide. JCC instruction uses relative 6 bits offset. An additional adder is implemented for this.
The instruction does not reset carry flag. ADD or SUB instructions should be used to reset the flag.
ADD, SUB, NOR, and LDA instructions use 5 bits address field.
STA instruction uses 6 bits address.
As a result the processor can use 32/64 data memory locations.
This processor has independent control lines for program memory and data memory.
As a result program memory and data memory can be separated if necessary.
The source code was written in VHDL (~300 sloc + test bench ~ 120 sloc).
The design is completed. All known bugs were fixed.
