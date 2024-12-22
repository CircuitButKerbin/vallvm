# Specification
## Vall Bytecode
### Instruction Format
Instructions are variable in size. The first byte of an instruction is the opcode, defining the
operation to be performed. The opcode is followed by zero or more operands. Operands are encoded as followed.
Byte 1: Operand type
0b0RPT_TTTT
R: if the data represents a register (type then represents the register number)
P: if the data represents a pointer (following instead of data will be a 32 bit int)
T: type of the data
### Simple Types
- `0x00` : `nil`
 - Simple Type representing a lua nil value
- `0x01` : `i16`
 - 16 bit signed integer (2 bytes)
- `0x02` : `i32`
 - 32 bit signed integer (4 bytes)
- `0x03` : `f32`
 - 32 bit floating point number (4 bytes)
- `0x05` : `bytes`
 - Byte array (2 bytes for length, followed by the bytes)
- `0x08` : `variable`
 - Null-terminated string; Pointer bit does not apply to this type 
- `0x09` : `register` 
 - Register number (internal)
### Complex Type - Table
`0x06` \: `table`

Table (2 bytes for number of key-value pairs, followed by the key-value pairs)
	
- `0x07` : `function`
	: Fear
### Instructions
- `0x01` - `push` - Pushes a value to the stack
- `0x02` - `pop` - Pops a value from the stack

- `0x03` - `add` - Adds two values from the stack
- `0x04` - `sub` - Subtracts two values from the stack
- `0x05` - `mul` - Multiplies two values from the stack
- `0x06` - `div` - Divides two values from the stack
- `0x07` - `mod` - Modulus of two values from the stack
- `0x08` - `and` - Bitwise and of two values from the stack
- `0x09` - `or` - Bitwise or of two values from the stack
- `0x0A` - `xor` - Bitwise xor of two values from the stack
- `0x0B` - `not` - Bitwise not of a value from the stack
- `0x0C` - `shl` - Bitwise shift left of two values from the stack
- `0x0D` - `shr` - Bitwise shift right of two values from the stack

- `0x10` - `eq` - Compares two values from the stack for equality
- `0x11` - `ne` - Compares two values from the stack for inequality
- `0x12` - `lt` - Compares two values from the stack for less than
- `0x13` - `gt` - Compares two values from the stack for greater than
- `0x14` - `le` - Compares two values from the stack for less than or equal to
- `0x15` - `ge` - Compares two values from the stack for greater than or equal to

- `0x16` - `load` - Loads a value from a variable to the stack
- `0x17` - `store` - Stores a value from the stack to a variable
- `0x18` - `move` - Moves a value from one variable to another

- `0x20` - `call` - Calls a function
- `0x21` - `ret` - Returns from a function
-# Note: on a Call, the callee is responsible for popping the arguments from the stack. The caller is responsible for popping the return value from the stack. After calling the stack size should be the same as before calling plus the returned values.
- `0x22` - `jmp` - Jumps to an address
- `0x23` - `jcc` - Jumps to an address if the stack is true (not zero)
- `0x24` - `jnc` - Jumps to an address if the stack is zero
- `0x25` - `jr`  - Jumps to an address relative to the current instruction
- `0x26` - `jcr` - Jumps to an address relative to the current instruction if the stack is true (not zero)
- `0x27` - `jncr`- Jumps to an address relative to the current instruction if the stack is zero
-# Note: on a Jump, the stack is not modified. The address is an offset from the start of the bytecode, or in the case of relative jumps, an offset from the current instruction.
- `0x28` - `invoke` - Calls a built-in function
-# Has three arguments, first being the function name, second being the number of arguments, third being the number of return values
- `0x29` - `yield` - Pauses the scripts execution
- `0x2A` - `fndef` - Defines a function



