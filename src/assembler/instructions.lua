--- Instructions for the assembler; assemble fn will crash outside assembler.lua's env
local exception = require("lib.error")
---@class unfinishedassembly: table
---@field type "UnfinishedAssembly"
---@field unfinished string
---@field key string

---@alias assembly string
---@alias buildfn fun(instruction:Instruction):assembly|unfinishedassembly

---comment
---@param operand operand
---@return string, string
---@throws assembler.compiler.InvalidOperandException, assembler.compiler.InvalidCastException
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
		assert(#instruction.operands == 1, string.format("Invalid number of operands for push at line %d", instruction.lineDefined))
		local operand = Try({packoperand, instruction.operands[1]}, function(e)
			Throw(exception.new("assembler.compiler.InvalidOperandException", string.format("Invalid operand for push at line %d", instruction.lineDefined)))
		end, nil)
		return "\x01" .. operand
	end,
	---@type buildfn
	["pop"] =  function (instruction)
		assert(#instruction.operands == 1, string.format("Invalid number of operands for pop at line %d", instruction.lineDefined))
		assert(instruction.operands[1].type == "string" or instruction.operands[1].type == "register", string.format("Invalid operand type for pop at line %d", instruction.lineDefined))
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
		assert(#instruction.operands == 1, string.format("Invalid number of operands for load at line %d", instruction.lineDefined))
		assert(instruction.operands[1].type == "string" or instruction.operands[1].type == "register")
		local operand;
		if (instruction.operands[1].type == "register") then
			operand = packoperand(instruction.operands[1], "register")
		elseif (instruction.operands[1].type == "string") then
			operand = packoperand(instruction.operands[1], "varaible")
		end
		return "\x16" .. operand
	end,
	["store"] = function (instruction)  
		assert(#instruction.operands == 1, string.format("Invalid number of operands for store at line %d", instruction.lineDefined))
		assert(instruction.operands[1].type == "string" or instruction.operands[1].type == "register", string.format("Invalid operand type for store at line %d", instruction.lineDefined))
		local operand;
		if (instruction.operands[1].type == "register") then
			operand = packoperand(instruction.operands[1], "register")
		elseif (instruction.operands[1].type == "string") then
			operand = packoperand(instruction.operands[1], "varaible")
		end
		return "\x17" .. operand
	end,
	["move"] = function (instruction)
		assert(#instruction.operands == 2, string.format("Invalid number of operands for move at line %d", instruction.lineDefined))
		assert(instruction.operands[1].type == "string" or instruction.operands[1].type == "register", string.format("Invalid operand 1 type for move at line %d", instruction.lineDefined))
		assert(instruction.operands[2].type == "string" or instruction.operands[2].type == "register", string.format("Invalid operand 1 type for move at line %d", instruction.lineDefined))
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
	["call"] = function (instruction)
		assert(#instruction.operands == 1, string.format("Invalid number of operands for call at line %d", instruction.lineDefined))
		assert(instruction.operands[1].type == "label", "Invalid operand type for call")
		return "\x20" .. packoperand(instruction.operands[1], "varaible")
	end,
	["ret"] = function (instruction) return "\x21" end,
	---@type buildfn
	["jmp"] = function(instruction) 
		assert(#instruction.operands == 1, string.format("Invalid number of operands for jmp at line %d", instruction.lineDefined))
		assert(instruction.operands[1].type == "label", "Invalid operand type for jmp")
		---@type unfinishedassembly	
		return { 
			unfinished = "\x22" .. "UABSJ",
			key = instruction.operands[1].value,
			type = "UnfinishedAssembly"
		}
	end,
	---@type buildfn
	["jcc"] = function(instruction) 
		assert(#instruction.operands == 1, string.format("Invalid number of operands for jcc at line %d", instruction.lineDefined))
		assert(instruction.operands[1].type == "label", "Invalid operand type for jcc")
		---@type unfinishedassembly	
		return { 
			unfinished = "\x23" .. "UABSJ",
			key = instruction.operands[1].value,
			type = "UnfinishedAssembly"
		}
	end,
	["jnc"] = function(instruction) 
		assert(#instruction.operands == 1, string.format("Invalid number of operands for jnc at line %d", instruction.lineDefined))
		assert(instruction.operands[1].type == "label", "Invalid operand type for jnc")
		---@type unfinishedassembly	
		return { 
			unfinished = "\x24" .. "UABSJ",
			key = instruction.operands[1].value,
			type = "UnfinishedAssembly"
		}
	end,
	["jr"] = function(instruction) 
		assert(#instruction.operands == 1, string.format("Invalid number of operands for jr at line %d", instruction.lineDefined))
		assert(instruction.operands[1].type == "label", "Invalid operand type for jr")
		---@type unfinishedassembly	
		return { 
			unfinished = "\x25" .. "URELJ",
			key = instruction.operands[1].value,
			type = "UnfinishedAssembly"
		}
	end,
	["jcr"] = function(instruction) 
		assert(#instruction.operands == 1, string.format("Invalid number of operands for jcr at line %d", instruction.lineDefined))
		assert(instruction.operands[1].type == "label", "Invalid operand type for jcr")
		---@type unfinishedassembly	
		return { 
			unfinished = "\x26" .. "URELJ",
			key = instruction.operands[1].value,
			type = "UnfinishedAssembly"
		}
	end,
	["jncr"] = function(instruction) 
		assert(#instruction.operands == 1, string.format("Invalid number of operands for jncr at line %d", instruction.lineDefined))
		assert(instruction.operands[1].type == "label", "Invalid operand type for jncr")
		---@type unfinishedassembly	
		return { 
			unfinished = "\x27" .. "URELJ",
			key = instruction.operands[1].value,
			type = "UnfinishedAssembly"
		}
	end,
	["invoke"] = function (instruction)
		assert(#instruction.operands == 3, string.format("Invalid number of operands for invoke at line %d", instruction.lineDefined))
		assert(instruction.operands[1].type == "string", "Invalid operand 1 type for invoke")
		assert(instruction.operands[2].type == "number", "Invalid operand 2 type for invoke")
		assert(instruction.operands[2].type == "number", "Invalid operand 3 type for invoke")
		return "\x28" .. packoperand(instruction.operands[1], "varaible") .. packoperand(instruction.operands[2], "i16") .. packoperand(instruction.operands[3], "i16")
	end,
	["yield"] =	 function (instruction) return "\x29" end,
	["fndef"] = function (instruction)
		assert(#instruction.operands == 1, string.format("Invalid number of operands for fndef at line %d", instruction.lineDefined))
		assert(instruction.operands[1].type == "label", "Invalid operand type for fndef")
		return "\x2A" .. packoperand(instruction.operands[1], "varaible")
	end,
}
return assemblers