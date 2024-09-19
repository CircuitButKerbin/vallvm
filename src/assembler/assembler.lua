local VERSION = "0.0.1"	
local inputDir = "./in"
local outputDir = "./out"
local parser = require("lib.parser")
local function formatprimative(v, bin)
	local redish = "\x1B[38;5;196m"
	local orange = "\x1B[38;5;136m"
	local green = "\x1B[38;5;2m"
	local pink = "\x1B[38;5;13m"
	local reset = "\x1B[0m"
	if (type(v) == "string") then
		--check for binary
		if (v:match('[^ -~\n\t]')) then
			local esc = green .. "\"" .. reset
			for i=1, #v do
				
				if (string.char(v:byte(i)):match('[^ -~]') or bin) then
					esc = esc .. redish .. string.format("\\x%02X", v:byte(i)) .. reset
				else
					esc = esc .. green .. string.char(v:byte(i)) .. reset
				end
			end
			return esc .. green .. "\"" .. reset
		end
		return green .. "\"" .. v .. "\"" .. reset
	elseif (type(v) == "number") then
		return orange .. v .. reset
	elseif (type(v) == "nil") then
		return pink .. "nil" .. reset
	elseif (type(v) == "boolean") then
		return orange .. tostring(v) .. reset
	elseif (type(v) == "function") then
		return pink .. "function" .. reset
	else
		return tostring(v)
	end
end
local function prettyPrintTable (table, indent)
	indent = indent or 0
	_ = (indent==0) and print(string.rep("    ", indent) .. "{")
	for k, v in pairs(table) do
		if (type(v) == "table") then
			print(string.rep("    ", indent) .. string.format("\t[%s] = {", formatprimative(k)))
			prettyPrintTable(v, indent + 2)
		else
			print(string.rep("    ", indent) .. string.format("\t[%s] = %s", formatprimative(k), formatprimative(v)))
		end
	end
	print(string.rep("    ", indent) .. "}")
end

---@class unfinishedassembly: table
---@field unfinished string
---@field key string

---@alias assembly string
---@alias buildfn fun(instruction:instruction):assembly|unfinishedassembly

---comment
---@param operand operand
---@return string, string
local function packoperand(operand, cast)
	if (operand.type == "nil") then
		
	elseif (operand.type == "number") then
		assert(cast == nil or cast == "i16" or cast == "i32" or cast == "f32", string.format("Cannot cast number to %s", cast))
		if (cast == "i16" or (not cast and (32767 >= operand.value) and (operand.value  >= -32768) and math.floor(operand.value) == operand.value)) then
			return "\x01" .. string.pack("i2", operand.value), "i16"
		elseif (cast == "i32" or (not cast and (math.maxinteger >= operand.value) and (operand.value >= math.mininteger) and (math.floor(operand.value) == operand.value))) then
			return "\x02" .. string.pack("i4", operand.value), "i32"
		else
			return "\x03" .. string.pack("f", operand.value), "f32"
		end
	elseif (operand.type == "string") then
		assert(cast == nil or cast == "varaible", string.format("Cannot cast string to %s", cast))
		if (cast == "varaible") then
			assert(not operand.value:match("\0"), string.format("Invalid varaible name"))
			return "\x08" .. operand.value .. "\0", "varaible"
		else
			return "\x05" .. string.pack("i2", #operand.value).. operand.value, "string"
		end
	elseif (operand.type == "label") then
		assert(cast == nil or cast == "varaible", string.format("Cannot cast label to %s", cast))
		assert(not operand.value:match("\0"), string.format("Invalid varaible name"))
		return "\x08" .. operand.value .. "\0", "varaible"
	elseif (operand.type == "register") then
		assert(cast == nil or cast == "register", string.format("Cannot cast register to %s", cast))
		assert(operand.value >= 0 and operand.value <= 31, string.format("Invalid register number"))
		return string.char(0x40 | (operand.value & 0x1F)), "register"
	else
		error(string.format("Maliformed operand"))
	end
	error("type_not_implemented: " .. operand.type)
end

local assemblers =  {
	---@type buildfn
	["push"] =	function (instruction)
		assert(#instruction.operands == 1, string.format("Invalid number of operands for push at line %d", instruction.line))
		local operand = packoperand(instruction.operands[1])
		return "\x01" .. operand
	end,
	---@type buildfn
	["pop"] =  function (instruction)
		assert(#instruction.operands == 1, string.format("Invalid number of operands for pop at line %d", instruction.line))
		assert(instruction.operands[1].type == "string" or instruction.operands[1].type == "register", string.format("Invalid operand type for pop at line %d", instruction.line))
		local operand;
		if (instruction.operands[1].type == "register") then
			operand = packoperand(instruction.operands[1], "register")
		elseif (instruction.operands[1].type == "varaible") then
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
		assert(#instruction.operands == 1, string.format("Invalid number of operands for load at line %d", instruction.line))
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
		assert(#instruction.operands == 1, string.format("Invalid number of operands for store at line %d", instruction.line))
		assert(instruction.operands[1].type == "string" or instruction.operands[1].type == "register", string.format("Invalid operand type for store at line %d", instruction.line))
		local operand;
		if (instruction.operands[1].type == "register") then
			operand = packoperand(instruction.operands[1], "register")
		elseif (instruction.operands[1].type == "string") then
			operand = packoperand(instruction.operands[1], "varaible")
		end
		return "\x17" .. operand
	end,
	["move"] = function (instruction)
		assert(#instruction.operands == 2, string.format("Invalid number of operands for move at line %d", instruction.line))
		assert(instruction.operands[1].type == "string" or instruction.operands[1].type == "register", string.format("Invalid operand 1 type for move at line %d", instruction.line))
		assert(instruction.operands[2].type == "string" or instruction.operands[2].type == "register", string.format("Invalid operand 1 type for move at line %d", instruction.line))
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
		assert(#instruction.operands == 1, string.format("Invalid number of operands for call at line %d", instruction.line))
		assert(instruction.operands[1].type == "label", "Invalid operand type for call")
		return "\x20" .. packoperand(instruction.operands[1], "varaible")
	end,
	["ret"] = function (instruction) return "\x21" end,
	---@type buildfn
	["jmp"] = function(instruction) 
		assert(#instruction.operands == 1, string.format("Invalid number of operands for jmp at line %d", instruction.line))
		assert(instruction.operands[1].type == "label", "Invalid operand type for jmp")
		---@type unfinishedassembly	
		return { 
			unfinished = "\x22" .. "UABSJ",
			key = instruction.operands[1].value
		}
	end,
	---@type buildfn
	["jcc"] = function(instruction) 
		assert(#instruction.operands == 1, string.format("Invalid number of operands for jcc at line %d", instruction.line))
		assert(instruction.operands[1].type == "label", "Invalid operand type for jcc")
		---@type unfinishedassembly	
		return { 
			unfinished = "\x23" .. "UABSJ",
			key = instruction.operands[1].value
		}
	end,
	["jnc"] = function(instruction) 
		assert(#instruction.operands == 1, string.format("Invalid number of operands for jnc at line %d", instruction.line))
		assert(instruction.operands[1].type == "label", "Invalid operand type for jnc")
		---@type unfinishedassembly	
		return { 
			unfinished = "\x24" .. "UABSJ",
			key = instruction.operands[1].value
		}
	end,
	["jr"] = function(instruction) 
		assert(#instruction.operands == 1, string.format("Invalid number of operands for jr at line %d", instruction.line))
		assert(instruction.operands[1].type == "label", "Invalid operand type for jr")
		---@type unfinishedassembly	
		return { 
			unfinished = "\x25" .. "URELJ",
			key = instruction.operands[1].value
		}
	end,
	["jcr"] = function(instruction) 
		assert(#instruction.operands == 1, string.format("Invalid number of operands for jcr at line %d", instruction.line))
		assert(instruction.operands[1].type == "label", "Invalid operand type for jcr")
		---@type unfinishedassembly	
		return { 
			unfinished = "\x26" .. "URELJ",
			key = instruction.operands[1].value
		}
	end,
	["jncr"] = function(instruction) 
		assert(#instruction.operands == 1, string.format("Invalid number of operands for jncr at line %d", instruction.line))
		assert(instruction.operands[1].type == "label", "Invalid operand type for jncr")
		---@type unfinishedassembly	
		return { 
			unfinished = "\x27" .. "URELJ",
			key = instruction.operands[1].value
		}
	end,
	["invoke"] = function (instruction)
		assert(#instruction.operands == 3, string.format("Invalid number of operands for invoke at line %d", instruction.line))
		assert(instruction.operands[1].type == "string", "Invalid operand 1 type for invoke")
		assert(instruction.operands[2].type == "number", "Invalid operand 2 type for invoke")
		assert(instruction.operands[2].type == "number", "Invalid operand 3 type for invoke")
		return "\x28" .. packoperand(instruction.operands[1], "varaible") .. packoperand(instruction.operands[2], "i16") .. packoperand(instruction.operands[3], "i16")
	end,
	["yield"] =	 function (instruction) return "\x29" end,
	["fndef"] = function (instruction)
		assert(#instruction.operands == 1, string.format("Invalid number of operands for fndef at line %d", instruction.line))
		assert(instruction.operands[1].type == "label", "Invalid operand type for fndef")
		return "\x2A" .. packoperand(instruction.operands[1], "varaible")
	end,
}

local function assembleParsed(parsed)
	local assembled = {}
	for i, instruction in ipairs(parsed) do
		local assembler;
		if (instruction.type == "instruction") then
			assembler = assemblers[instruction.name:lower()]
			assert(assembler, string.format("Invalid instruction %s at line %d", instruction.name, instruction.line))
			assembled[#assembled+1] = assembler(instruction)
		elseif (instruction.type == "label") then
			local eninstruction = instruction.instruction
			assembler = assemblers[eninstruction.name:lower()]
			assert(assembler, string.format("Invalid instruction %s at line %d", eninstruction.name, eninstruction.line))
			assembled[#assembled+1] = {assembler(eninstruction), instruction.name}
		end
	end
	-- pass two | combine chunks
	local chunks = {}
	local chunk = ""
	for i, v in ipairs(assembled) do
		if (type(v) == "string") then
			chunk = chunk .. v
		else
			chunks[#chunks+1] = chunk
			chunks[#chunks+1] = v
			chunk = ""
		end
	end
	if (#chunk > 0) then
		chunks[#chunks+1] = chunk
	end
	local start = 0
	-- resolve labels
	for i, v in ipairs(chunks) do
		if (type(v) == "table" and v.unfinished) then
			local key = v.key
			local found = false
			local label = 0
			for j, w in ipairs(chunks) do
				if (type(w) == "table" and w[2] == key) then
					local jloc
					if (v.unfinished:find("URELJ")) then
						jloc = label - start
						if (jloc < 0) then
							jloc = jloc - 14
						end
					else
						jloc = label
					end
					chunks[i] = v.unfinished:sub(1, 1) .. "\x02".. string.pack("i4", jloc + 6)
					chunks[j] = chunks[j][1]
					found = true
					break
				end
				label = label + #w
			end
			assert(found, string.format("Could not find label %s", key))
		end
		start = start + #v
	end
	assembled = chunks
	chunks = {}
	prettyPrintTable(assembled)
	for i, v in ipairs(assembled) do
		if (type(v) == "string") then
			chunk = chunk .. v
		else
			chunks[#chunks+1] = chunk
			chunks[#chunks+1] = v
			chunk = ""
		end
	end
	assert(#chunks==0, "Failed to resolve all labels")
	return chunk
end

local function dbg()
	local h = io.open(inputDir .. "/test.vallasm", "r")
	assert(h, "Could not open input file")	
	Parsed = parser.parseVallASM(h:read("all"), {})
	prettyPrintTable(Parsed)
	local assembled = assembleParsed(Parsed)
	h:close()
	local h = io.open(outputDir .. "/test.val", "wb")
	assert(h, "Could not open output file")
	h:write(assembled)
	print(formatprimative(assembled, true))
	h:close();
end


function Main()
	if (arg[1] == "-h" or arg[1] == "--help" or arg[1] == "-?" or arg[1] == nil) then
		print("Usage: assembler.lua [options] file")
		print("Options:")
		print("\t--help\t\tDisplay this help message")
		print("\t--version\tDisplay version information")
		print("\t-o <file>\tOutput to file")
		return
	end
	if (arg[1] == "--debug_test") then
		dbg()
		return
	end
	if (arg[1] == "--version") then
		print(string.format("assembler.lua version %s\n%s", VERSION, _VERSION))
		return
	end
	---@overload fun(key:string):any
	local function getarg(key, isFlag)
		for k, v in ipairs(arg) do
			if (v == key) then
				if (isFlag) then
					return true
				end
				return arg[k+1]
			end
		end
	end
	local inputfile = arg[#arg]
	local tmp = getarg("-o")
	local outputfile = tmp and (tmp:match("/") and tmp or ("./out/" .. tmp)) or ("./out/" .. inputfile:gsub("%..*", ".val"))
	if (not inputfile:match("/")) then
		inputfile = "./in/" .. inputfile
	end
	print(string.format("Assembling %s to %s", inputfile, outputfile))
	local h = io.open(inputfile, "r")
	assert(h, "Could not open input file")
	local Parsed = parser.parseVallASM(h:read("all"), {})
	h:close()
	local assembled = assembleParsed(Parsed)
	local h = io.open(outputfile, "wb")
	assert(h, "Could not open output file")
	h:write(assembled)
	h:close()
end


Main()