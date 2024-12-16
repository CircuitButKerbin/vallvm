---@class Operand
---@field type string
---@field value any


---@class DecompiledInstruction
---@field opcode number
---@field operands table<operand>



---@type table[int]<>
local opParser = {
	[0x01] = function (bytecode, location)
		return {type="i16", value=string.unpack("i2", bytecode:sub(location+1, location+2))}, 2
	end,
	[0x02] = function (bytecode, location)
		return {type="i32", value=string.unpack("i4", bytecode:sub(location+1, location+4))}, 4
	end,
	[0x03] = function (bytecode, location)
		return {type="f32", value=string.unpack("f", bytecode:sub(location+1, location+4))}, 4
	end,
	[0x04] = function (bytecode, location)
		return {type="f64", value=string.unpack("d", bytecode:sub(location+1, location+8))}, 8
	end,
	[0x05] = function (bytecode, location)
		local len = string.unpack("i2", bytecode:sub(location+1, location+2))
		return {type="string", value=bytecode:sub(location+3, location+2+len)}, len+2
	end,
	[0x08] = function (bytecode, location)
		local str = string.unpack("z", bytecode:sub(location+1))
		return {type="global", value=str}, #str + 1
	end,
}
local function unpackOperand(bytecode, location)
	return opParser[bytecode:byte(location)](bytecode, location)
end

local function unpackOperandSeries(bytecode, location, count)
	local operands = {}
	if count == 1 then
		local operand, len = unpackOperand(bytecode, location)
		operands[#operands+1] = operand
		return operands, len + 1
	end
	local offset = 0
	for i=1, count do
		local operand, len = unpackOperand(bytecode, location+offset)
		operands[#operands+1] = operand
		offset = offset + len + 1
	end
	return operands, offset
end

local instructionmap = {
	-- byte -> string
	[0x01] = "push",
	[0x02] = "pop",
	[0x03] = "add",
	[0x04] = "sub",
	[0x05] = "mul",
	[0x06] = "div",
	[0x07] = "mod",
	[0x08] = "and",
	[0x09] = "or",
	[0x0A] = "xor",
	[0x0B] = "not",
	[0x0C] = "shl",
	[0x0D] = "shr",
	[0x10] = "eq",
	[0x11] = "ne",
	[0x12] = "lt",
	[0x13] = "gt",
	[0x14] = "le",
	[0x15] = "ge",
	[0x16] = "load",
	[0x17] = "store",
	[0x18] = "move",

	[0x19] = "swap",
	[0x1A] = "dupe",
	[0x1B] = "drop",
	[0x1C] = "over",

	[0x20] = "call",
	[0x21] = "ret",
	[0x22] = "jmp",
	[0x23] = "jcc",
	[0x24] = "jnc",
	[0x25] = "jr",
	[0x26] = "jcr",
	[0x27] = "jncr",
	[0x28] = "invoke",
	[0x29] = "yield",
	[0x2A] = "fndef",
	[0x30] = "bp",
	[0x31] = "nop",
	-- string -> byte
	["push"] =	0x01,
	["pop"] =	0x02,
	["add"] =	0x03,
	["sub"] =	0x04,
	["mul"] =	0x05,
	["div"] =	0x06,
	["mod"] =	0x07,
	["and"] =	0x08,
	["or"] =	0x09,
	["xor"] =	0x0A,
	["not"] =	0x0B,
	["shl"] =	0x0C,
	["shr"] =	0x0D,
	["eq"] =	0x10,
	["ne"] =	0x11,
	["lt"] =	0x12,
	["gt"] =	0x13,
	["le"] =	0x14,
	["ge"] =	0x15,
	["load"] =	0x16,
	["store"] =	0x17,
	["move"] =	0x18,

	["swap"] =  0x19,
	["dupe"] =  0x1A,
	["drop"] =  0x1B,
	["over"] =  0x1C,

	["call"] =	0x20,
	["ret"] =	0x21,
	["jmp"] =	0x22,
	["jcc"] =	0x23,
	["jnc"] =	0x24,
	["jr"] =	0x25,
	["jcr"] =	0x26,
	["jncr"] =	0x27,
	["invoke"] =0x28,
	["yield"] =	0x29,
	["fndef"] = 0x2A,
	["bp"] =	0x30,
	["nop"] =	0x31
}

local instructionArgLengths = {
	[0x01] = 1,
	[0x02] = 1,
	[0x16] = 1,
	[0x17] = 1,
	[0x18] = 2,
	[0x20] = 1,
	[0x22] = 1,
	[0x23] = 1,
	[0x24] = 1,
	[0x25] = 1,
	[0x26] = 1,
	[0x27] = 1,
	[0x28] = 3,
	[0x2A] = 1
}

function DecodeInstruction(bytecode, location)
	local opcode = bytecode:byte(location)
	if not opcode then
		return nil, 0
	end
	if (0x15 >= opcode and opcode >= 0x03) or (0x1C >= opcode and opcode >= 0x19) or (opcode == 0x30 or opcode == 0x31) or (opcode == 0x21) or (opcode == 0x29) then -- argumentless instructions 
		return {opcode=opcode, name=instructionmap[opcode], operands={}}, 1
	end
	local argLength = instructionArgLengths[opcode] or 0
	local operands, len = unpackOperandSeries(bytecode, location+1, argLength)
	if (not instructionmap[opcode]) then
		error ("Unknown opcode: " .. opcode)
	end
	return {opcode=opcode, name=instructionmap[opcode], operands=operands}, len+1
end

return {
	DecodeInstruction = DecodeInstruction
}