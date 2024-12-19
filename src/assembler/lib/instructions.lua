--- Instructions for the assembler; assemble fn will crash outside assembler.lua's env
local exception = require("lib.error")
---@class unfinishedassembly: table
---@field type "UnfinishedAssembly"
---@field referencedLabel string
---@field opcode number	
---@field finish fun(address:integer, is_i32:boolean):string

---@alias assembly string
---@alias buildfn fun(instruction:Instruction):assembly|unfinishedassembly

--#region Assembler

---comment
---@param operand operand
---@return string, string
---@throws assembler.compiler.InvalidOperandException, assembler.compiler.InvalidCastException


---comment
---@param instruction Instruction instruction to check
---@param ... string|table<string> expected type(s)
local function ExpectOperands(instruction, ...)
	if (#instruction.operands ~= select("#", ...)) then
		Throw(exception.new("assembler.compiler.InvalidOperandException", string.format("Invalid number of operands for %s at line %d", instruction.name, instruction.lineDefined)))
	end
	for i, v in ipairs(instruction.operands) do
		local expected = (...)[i]
		if (type(expected) == "table") then
			local found = false
			for _, t in ipairs(expected) do
				if (v.type == t) then
					found = true
					break
				end
			end
			if (not found) then
				Throw(exception.new("assembler.compiler.InvalidOperandException", string.format("Invalid operand type for %s at line %d", instruction.name, instruction.lineDefined)))
			end
		elseif (v.type ~= expected) and not "any" then
			Throw(exception.new("assembler.compiler.InvalidOperandException", string.format("Invalid operand type for %s at line %d", instruction.name, instruction.lineDefined)))
		end
	end
end

local function packoperand(operand, cast)
	if (operand.type == "nil") then
		--#TODO: implement nil
	elseif (operand.type == "number") then
		Assert(cast == nil or cast == "i16" or cast == "i32" or cast == "f32", exception.new("assembler.compiler.InvalidCastException", string.format("Cannot cast number to %s", cast)))
		if (cast == "i16" or (not cast and (32767 >= operand.value) and (operand.value  >= -32768) and math.floor(operand.value) == operand.value)) then
			return "\x01" .. string.pack("i2", operand.value), "i16"
		elseif (cast == "i32" or (not cast and (math.maxinteger >= operand.value) and (operand.value >= math.mininteger) and (math.floor(operand.value) == operand.value))) then
			return "\x02" .. string.pack("i4", operand.value), "i32"
		else
			return "\x03" .. string.pack("f", operand.value), "f32"
		end
	elseif (operand.type == "string") then
		Assert(cast == nil or cast == "varaible", exception.new("assembler.compiler.InvalidCastException", string.format("Cannot cast string to %s", cast)))
		if (cast == "varaible") then
			Assert(not operand.value:match("\0"), exception.new("assembler.compiler.InvalidOperandException", string.format("Operand type 0x08 cannot contain null characters")))
			return "\x08" .. operand.value .. "\0", "varaible"
		else
			return "\x05" .. string.pack("i2", #operand.value).. operand.value, "string"
		end
	elseif (operand.type == "label") then
		Assert(cast == nil or cast == "varaible", exception.new("assembler.compiler.InvalidCastException", string.format("Cannot cast label to %s", cast)))
		Assert(not operand.value:match("\0"), exception.new("assembler.compiler.InvalidOperandException", string.format("Operand type 0x08 cannot contain null characters")))
		return "\x08" .. operand.value .. "\0", "varaible"
	elseif (operand.type == "register") then
		Assert(cast == nil or cast == "register", exception.new("assembler.compiler.InvalidCastException", string.format("Cannot cast register to %s", cast)))
		Assert(operand.value >= 0 and operand.value <= 31, exception.new("assembler.compiler.InvalidOperandException", string.format("Invalid register number %d", operand.value)))
		return string.char(0x40 | (operand.value & 0x1F)), "register"
	else
		Throw(exception.new("assembler.compiler.InvalidOperandException", string.format("Invalid operand type %s", operand.type)))
	end
	error("unreachable")
end

--- @type table<buildfn>
local assemblers =  {
	---@type buildfn
	["push"] =	function (instruction)
		ExpectOperands(instruction, "any")
		local operand = packoperand(instruction.operands[1])
		return "\x01" .. operand
	end,
	---@type buildfn
	["pop"] =  function (instruction)
		ExpectOperands(instruction, {"register", "string", "label"})
		local operand;
		if (instruction.operands[1].type == "register") then
			operand = packoperand(instruction.operands[1], "register")
		elseif (instruction.operands[1].type == "string") then
			operand = packoperand(instruction.operands[1], "varaible")
		end
		return "\x02" .. operand
	end,
	["add"] = 	function (instruction) return "\x03" end,
	["sub"] = 	function (instruction) return "\x04" end,
	["mul"] = 	function (instruction) return "\x05" end,
	["div"] = 	function (instruction) return "\x06" end,
	["mod"] = 	function (instruction) return "\x07" end,
	["and"] = 	function (instruction) return "\x08" end,
	["or"] =  	function (instruction) return "\x09" end,
	["xor"] = 	function (instruction) return "\x0A" end,
	["not"] = 	function (instruction) return "\x0B" end,
	["shl"] = 	function (instruction) return "\x0C" end,
	["shr"] = 	function (instruction) return "\x0D" end,
	["eq"] =  	function (instruction) return "\x10" end,
	["ne"] =  	function (instruction) return "\x11" end,
	["lt"] =  	function (instruction) return "\x12" end,
	["gt"] =  	function (instruction) return "\x13" end,
	["le"] =  	function (instruction) return "\x14" end,
	["ge"] =  	function (instruction) return "\x15" end,
	---@type buildfn
	["load"] =	function (instruction)  
		ExpectOperands(instruction, {"register", "string", "label"})
		local operand;
		if (instruction.operands[1].type == "register") then
			operand = packoperand(instruction.operands[1], "register")
		elseif (instruction.operands[1].type == "string") then
			operand = packoperand(instruction.operands[1], "varaible")
		end
		return "\x16" .. operand
	end,
	["store"] = function (instruction)  
		ExpectOperands(instruction, {"register", "string", "label"})
		local operand;
		if (instruction.operands[1].type == "register") then
			operand = packoperand(instruction.operands[1], "register")
		elseif (instruction.operands[1].type == "string") then
			operand = packoperand(instruction.operands[1], "varaible")
		end
		return "\x17" .. operand
	end,
	["move"] = function (instruction)
		ExpectOperands(instruction, {"register", "string", "label"}, {"register", "string", "label"})
		local operand = {};
		if (instruction.operands[1].type == "register") then
			operand[1] = packoperand(instruction.operands[1], "register")
		elseif (instruction.operands[1].type == "varaible") then
			operand[1] = packoperand(instruction.operands[1], "varaible")
		end
		if (instruction.operands[1].type == "register") then
			operand[2] = packoperand(instruction.operands[2], "register")
		elseif (instruction.operands[1].type == "varaible") then
			operand[2] = packoperand(instruction.operands[2], "varaible")
		end
		return "\x18" .. operand[1] .. operand[2]
	end,

	["swap"] = function (instruction) return "\x19" end,
	["dupe"] = function (instruction) return "\x1A" end,
	["drop"] = function (instruction) return "\x1B" end,
	["over"] = function (instruction) return "\x1C" end,

	["call"] = function (instruction)
		ExpectOperands(instruction, "label")
		return "\x20" .. packoperand(instruction.operands[1], "varaible")
	end,
	["ret"] = function (instruction) return "\x21" end,
	---@type buildfn
	["jmp"] = function(instruction) 
		ExpectOperands(instruction, "label")
		---@type unfinishedassembly	
		return { 
			referencedLabel = instruction.operands[1].value,
			opcode = 0x22,
			type = "UnfinishedAssembly",
			placeholder = "\x22\0\xff\xff",
			is_relative = false,
			finish = function (address, is_i32)
				return "\x22" .. packoperand({type="number", value=address}, is_i32 and "i32" or "i16")
			end
		}
	end,
	---@type buildfn
	["jcc"] = function(instruction) 
		ExpectOperands(instruction, "label")
		---@type unfinishedassembly	
		return { 
			referencedLabel = instruction.operands[1].value,
			opcode = 0x23,
			type = "UnfinishedAssembly",
			placeholder = "\x23\0\xff\xff",
			is_relative = false,
			finish = function (address, is_i32)
				return "\x23" .. packoperand({type="number", value=address}, is_i32 and "i32" or "i16")
			end
		}
	end,
	["jnc"] = function(instruction) 
		ExpectOperands(instruction, "label")
		---@type unfinishedassembly	
		return {
			referencedLabel = instruction.operands[1].value,
			opcode = 0x24,
			type = "UnfinishedAssembly",
			placeholder = "\x24\0\xff\xff",
			is_relative = false,
			finish = function (address, is_i32)
				return "\x24" .. packoperand({type="number", value=address}, is_i32 and "i32" or "i16")
			end
		}
	end,
	["jr"] = function(instruction) 
		ExpectOperands(instruction, "label")
		---@type unfinishedassembly	
		return {
			referencedLabel = instruction.operands[1].value,
			opcode = 0x25,
			type = "UnfinishedAssembly",
			placeholder = "\x25\0\xff\xff",
			is_relative = true,
			finish = function (address, is_i32)
				return "\x25" .. packoperand({type="number", value=address}, is_i32 and "i32" or "i16")
			end
		}
	end,
	["jcr"] = function(instruction) 
		ExpectOperands(instruction, "label")
		---@type unfinishedassembly	
		return {
			referencedLabel = instruction.operands[1].value,
			opcode = 0x26,
			type = "UnfinishedAssembly",
			placeholder = "\x26\0\xff\xff",
			is_relative = true,
			finish = function (address, is_i32)
				return "\x26" .. packoperand({type="number", value=address}, is_i32 and "i32" or "i16")
			end
		}
	end,
	["jncr"] = function(instruction) 
		ExpectOperands(instruction, "label")
		---@type unfinishedassembly	
		return {
			referencedLabel = instruction.operands[1].value,
			opcode = 0x27,
			placeholder = "\x27\0\xff\xff",
			is_relative = true,
			type = "UnfinishedAssembly",
			finish = function (address, is_i32)
				return "\x27" .. packoperand({type="number", value=address}, is_i32 and "i32" or "i16")
			end
		}
	end,
	["invoke"] = function (instruction)
		ExpectOperands(instruction, "string", "number", "number")
		return "\x28" .. packoperand(instruction.operands[1], "varaible") .. packoperand(instruction.operands[2], "i16") .. packoperand(instruction.operands[3], "i16")
	end,
	["yield"] =	 function (instruction) return "\x29" end,
	["fndef"] = function (instruction)
		ExpectOperands(instruction, "label")
		return "\x2A" .. packoperand(instruction.operands[1], "varaible")
	end,
	["bp"] = function (instruction) return "\x30" end,
	["nop"] = function (instruction) return "\x31" end
}

---@type fun(instruction:Instruction):assembly|unfinishedassembly
local function assembleInstruction(instruction)
	local assembler = assemblers[instruction.name:lower()]
	Assert(assembler, exception.new("assembler.compiler.InvalidInstructionException", string.format("Invalid instruction %s at line %d", instruction.name, instruction.lineDefined)))
	return assembler(instruction)
end

--#endregion Assembler

--#region Disassemblers

---Returns instruction, next
---@param binary string
---@param location number
---@return Instruction, number
local function disassembleInstruction(binary, location)

end

--#endregion Disassemblers
return {
	assembleInstruction = assembleInstruction,
	disassembleInstruction = disassembleInstruction
}