local parser = {}

local TEST = 
"fnDef init:				;\x2A\x08init\0\x01\0\0\n\z
	push \"Hello, world!\";\x16\x05\x0D\x00Hello, world!\n\z
	invoke \"print\", 1, 0;\x28\x08print\0\x01\x01\0\x01\0\0\n\z
	ret			        ;\x21\0\n\z
db 0,0\n\z
fnDef onTick:					  ;\x2A\x08onTick\0\x01\0\0\n\z
	push 1						  ;\x01\x01\x01\0\n\z
	invoke \"getBool\", 1, 1	      ;\x28\x08getBool\0\x01\x01\0\x01\x01\0\n\z
	jncr skp						  ;\x27\x01\x2D\x00 \n\z-\n\z- 4 bytes\n\z
	push \"The screen was touched!\";\x01\x05\x17\x00The screen was touched! -- 27 bytes\n\z
	invoke \"print\", 1, 0		  ;\x28\x08print\0\x01\x01\0\x01\0\0 -- 14 bytes\n\z
skp: ret							  ;\x21\0"



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
	["fndef"] = 0x2A
}
local function split(str, sep)
	local sep, fields = sep or ":", {}
	local pattern = string.format("([^%s]+)", sep)
	str:gsub(pattern, function(c) fields[#fields+1] = c end)
	return fields
end

local function trim (s)
	return (string.gsub(s, "^%s*(.-)%s*$", "%1"))
end

---@class operand
---@field type string
---@field value any

---@class instruction
---@field line number
---@field operands table<operand>
---@field type string
---@field name string
---@field opcode number

---@param input string
---@param args table<any>
---@return table<instruction>
local function parseVallASM (input, args)
	print("inputLen: " .. #input)
	local parsed = {}
	--first pass
	local lines = split(input, "\n")
	for i, line in ipairs(lines) do
		line = line:gsub(";.*", "")
		line = trim(line)
		local operation = line:match("%S+"):lower()
		local function getOperand(s) 
			local operandList = s:sub(select(1,s:find(" ")+1), #line)
			local escString = {}
			local next = 1
			while operandList:find("%b\"\"", next) do
				_, next = operandList:find("%b\"\"", next)
				local str = operandList:match("%b\"\"")
				operandList = operandList:gsub(str, string.format("STR_%02X", #escString + 1))
				str = str:gsub("\"", "")
				escString[#escString+1] = str
			end
			local list = split(operandList, ", ")
			for i=1, (#escString > 0 and #escString or 1) do
				for j=1, #list do
					--go ahead and assign types
					local tmp = {}
					if (list[j]:match("r%d") and not tmp.type) then
						tmp.type = "register"
						tmp.value = tonumber(list[j]:match("%d"))
					end
					if (list[j] == string.format("STR_%02X", i) and not tmp.type) then
						list[j] = escString[i]
						tmp.type = "string"
						tmp.value = escString[i]
					end
					if (list[j]:match("%-?%d*%.?%d+") and not tmp.type) then
						tmp.type = "number"
						tmp.value = tonumber(list[j]:match("%-?%d*%.?%d+"))
					end
					if (list[j]:match("0x%x+") and not tmp.type) then
						tmp.type = "hex"
						tmp.value = tonumber(list[j]:match("0x%x+"))
					end
					if (list[j]:match("[%w_]:$") and not tmp.type) then
						tmp.type = "label"
						tmp.value = list[j]:match("[%w_]+")
					end
					if (list[j]:match("[%w_]+") and not tmp.type) then
						tmp.type = "label"
						tmp.value = list[j]
					end
					list[j] = tmp
				end
			end
			return list
		end
		local function parseInstruction(s) 
			assert(instructionmap[s], string.format("Unknown instruction \'%s\'at line %d", s,i))
			local instruction = {
				type = "instruction",
				name = s:upper(),
				opcode = instructionmap[s:lower()],
				operands = line:find(" ") and getOperand(line) or {},
				line = i
			}
			return instruction
		end

		if (instructionmap[operation]) then
			parsed[#parsed+1] = parseInstruction(operation)
			line = ""
		end
		
		if (operation:match("[%w_]:$")) then
		--label
			local label = {
				type = "label",
				name = operation:match("[%w_]+"),
				line = i,
			}
			if (line:find(" ")) then
				local instruction = line:sub(select(1,line:find(" ")+1), #line)
				label.instruction = parseInstruction(instruction)
			end
			parsed[#parsed+1] = label
			line = "";
		end
		--directive
		if (operation == "db") then
			--#TODO
			line = ""
		end
		--end directive
		print(line)
		assert(#line == 0, string.format("Maliformed line on line %d", i))
	end
	return parsed
end


return {
	parseVallASM = parseVallASM
}
