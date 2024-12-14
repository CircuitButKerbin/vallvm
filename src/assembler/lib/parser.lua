require("lib.utilitys")
local parser = {}


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
local function split(str, sep)
	local sep, fields = sep or ":", {}
	local pattern = string.format("([^%s]+)", sep)
	str:gsub(pattern, function(c) fields[#fields+1] = c end)
	return fields
end

---@class operand
---@field type string
---@field value any

---@class Instruction
---@field lineDefined number
---@field operands table<operand>
---@field type "instruction"
---@field name string
---@field opcode number

---@class Label
---@field type "label"
---@field name string
---@field lineDefined number

---@class LabelArray: table
---@field type "labelArray"

---@class ParsedLine
---@field type "parsedline"
---@field lineDefined number
---@field labels LabelArray | nil
---@field instruction Instruction | nil

---@class ParsedMacro
---@field type "parsedmacro"
---@field lineDefined number
---@field lines table<ParsedLine>



local function parseOperands(operands) 
	local escString = {}
	local next = 1
	while operands:find("%b\"\"", next) do
		_, next = operands:find("%b\"\"", next)
		local str = operands:match("%b\"\"")
		local _str = str:gsub("%%", "%%%1")
		operands = operands:gsub(_str, string.format("STR_%02X", #escString + 1))
		str = str:gsub("\"", "")
		escString[#escString+1] = str
	end
	local list = split(operands, ", ")
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
				tmp.type = "number"
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

---comment
---@param s any
---@return Instruction
local function parseInstruction(s)
	local opi, opj = s:find("^[%w%%]+")
	print(s)
	local operation = s:sub(opi, opj)
	local operands = s:sub(opj+1, #s)
	operation = operation:gsub("^%s*(.-)%s*$", "%1")
	operands = operands:gsub("^%s*(.-)%s*$", "%1")
	local instruction = {
		type = "instruction",
		name = operation:upper(),
		opcode = instructionmap[operation:lower()],
		operands = operands ~= "" and parseOperands(operands) or {},
	}
	return instruction
end

---@param lineString string
---@param lineNumber number
---@return ParsedLine | ParsedMacro
local function parseLine(lineString, lineNumber)
	if (lineString:find(";")) then
		lineString = lineString:sub(1, select(1, lineString:find(";"))-1)
	end
	local label = ""
	lineString = lineString:gsub("^%s*(.-)%s*$", "%1")
	if (lineString:find("^%%")) then
		return {
			type = "parsedmacro",
			lineDefined = lineNumber,
			lines = ParseDirective(lineString, lineNumber)
		}
	end
	if (lineString:find("^%w+:")) then
		---@diagnostic disable-next-line This must exist or it'll never be exectuted :p
		label = lineString:sub(lineString:find("^%w+:"))
		label = label:gsub(":", "")
		lineString = lineString:sub(select(-1, lineString:find("^%w+:"))+1, #lineString)
	end
	local instruction;
	if lineString ~= "" then
		instruction = parseInstruction(lineString:gsub("^%s*(.-)%s*$", "%1"))
		instruction.lineDefined = lineNumber
	else
		instruction = nil
	end
	if #label > 0  then
		---@type ParsedLine
		return {
			type = "parsedline",
			lineDefined = lineNumber,
			labels = {
				type = "labelArray",
				{
					type = "label",
					name = label,
					lineDefined = lineNumber
				}
			},
			instruction = instruction
		}
	else
		---@type ParsedLine
		return {
			type = "parsedline",
			lineDefined = lineNumber,
			instruction = instruction,
			labels = {
				type = "labelArray"
			}
		}
	end
end

---@return table<ParsedLine>
function ParseDirective(s, lineNumber)
	if (s:find("^%%luaCall")) then
		local _, j = s:find("^[%w%%]+")
		local args = parseOperands(s:sub(j+1, #s):gsub("^%s*(.-)%s*$", "%1"))
		local rets = 0
		local expanded = {}
		local fn = ""
		prettyPrintTable(args)
		for i, v in ipairs(args) do
			if (i == #args) then
				assert(v.type == "number", "Last argument must be a number")
				rets = v.value
				break
			end
			if (i == 1) then
				assert(v.type == "string" or v.type == "label", "First argument must be a string")
				fn = v.value
			else
				if (v.type == "string") then
					expanded[#expanded+1] = parseLine(string.format("push \"%s\"", v.value), lineNumber)
				end
				if (v.type == "number") then
					expanded[#expanded+1] = parseLine(string.format("push %f", v.value), lineNumber)
				end
				if (v.type == "label") then
					expanded[#expanded+1] = parseLine(string.format("push %s", v.value), lineNumber)
				end
			end
		end
		expanded[#expanded+1] = parseLine(string.format("invoke \"%s\", %d, %d", fn ,#args-1, rets), lineNumber)
		return expanded
	end
	error("Invalid directive")
end


---@param input string
---@param args table<any>
---@return table<ParsedLine>
local function parseVallASM (input, args)
	---@type table<ParsedLine>
	local parsed = {}
	--first pass
	local lines = split(input, "\n")
	local meta = {
		labels = {},
		functions = {}
	}
	local emptyLabels = {}
	local emptyLabel = false
	print("Parsing Input")
	print("")
	for i, line in ipairs(lines) do
		--#TODO: Add support for macros
		if (line) then
			printf("\x1B[1AParsing line %d/%d", i, #lines)
			local lineParsed = parseLine(line, i)
			if (lineParsed.type == "parsedmacro") then
				for j, v in ipairs(lineParsed.lines) do
					if (j == 1) then
						if (emptyLabel) then
							parsed[#parsed+1] = v
							emptyLabel = false
							parsed[#parsed].labels = emptyLabels
						end
					else
						parsed[#parsed+1] = v
					end
				end
			else
				if (#lineParsed.labels > 0 and lineParsed.instruction == nil) then
					emptyLabel = true
					emptyLabels[#emptyLabels+1] = lineParsed.labels[1];
				end
				if (lineParsed.instruction and emptyLabel) then
					emptyLabel = false
					emptyLabels[#emptyLabels+1] = lineParsed.labels[1]
					lineParsed.labels = emptyLabels
					lineParsed.labels.type = "labelArray"
					emptyLabels = {}
					parsed[#parsed+1] = lineParsed
				elseif (lineParsed.instruction) then
					parsed[#parsed+1] = lineParsed
				end
			end
		end
	end
	if (emptyLabel) then
		printf("%s:%d \x1B[35mwarning:\x1B[0m empty label at EOF; label will be undefined!", args.filename, parsed[#parsed].labels[1].lineDefined)
		parsed[#parsed].labels = {}
	end
	prettyPrintTable(parsed)
	return parsed
end

---@param str string parse table string
---@return table | nil
local function parseTableString(str)

end


return {
	parseVallASM = parseVallASM
}
