#include <std/string.pat>

enum DataType : u8 {
    nil = 0,
    i16 = 1,
    i32 = 2,
    f32 = 3,
    bytes = 5,
    label = 8,
    register = 9,
    
};

enum Opcode : u8 {
	PUSH = 0x01,
	POP = 0x02,
	ADD = 0x03,
	SUB = 0x04,
	MUL = 0x05,
	DIV = 0x06,
	MOD = 0x07,
	AND = 0x08,
	OR = 0x09,
	XOR = 0x0A,
	NOT = 0x0B,
	SHL = 0x0C,
	SHR = 0x0D,
	EQ = 0x10,
	NE = 0x11,
	LT = 0x12,
	GT = 0x13,
	LE = 0x14,
	GE = 0x15,
	LOAD = 0x16,
	STORE = 0x17,
	MOVE = 0x18,
	SWAP = 0x19,
	DUPE = 0x1A,
	DROP = 0x1B,
	OVER = 0x1C,
	CALL = 0x20,
	RET = 0x21,
	JMP = 0x22,
	JCC = 0x23,
	JNC = 0x24,
	JR = 0x25,
	JCR = 0x26,
	JNCR = 0x27,
	INVOKE = 0x28,
	YIELD = 0x29,
	FNDEF = 0x2A,
	BP = 0x30,
	NOP = 0x31
};

struct BinaryData {
    u16 length;
    char data[length];
};

struct Data {
    DataType type;
    match (type) {
        (DataType::i16): s16 value;
        (DataType::i32): s32 value;
        (DataType::f32): float value;
        (DataType::bytes): BinaryData value;
        (DataType::label): char value[];
    }
};
struct Instruction {
    Opcode op;
    match (op) {
        (1 | 2 | 0x16 | 0x17 | 0x20 | 0x22 ... 0x27 | 0x2A): Data args[1];
        (0x18): Data args[2];
        (0x28): Data args[3];
    }
} [[single_color, name(std::format("{}", op))]];
Instruction Program[while(!std::mem::eof())] @ 0 ;