---@param v any value to format
---@param bin any 
---@return string
---@overload fun(v: string): string
function formatprimative(v, bin)
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
		local fstr = debug.getinfo(v).what
		if (fstr == "C") then
			fstr = "fn<C>"
		else
			fstr = "fn<Lua> " .. debug.getinfo(v).source .. ":" .. debug.getinfo(v).linedefined
		end
		return pink .. fstr .. reset
	elseif (type(v) == "userdata") then
		return pink .. "userdata" .. reset
	elseif (type(v) == "thread") then	
		return pink .. "thread" .. reset
	else
		return tostring(v)
	end
end
function prettyPrintTable (T, indent, displayed)
	indent = indent or 0
	local displayed = displayed or {}
	displayed[T] = true
	_ = (indent==0) and print(string.rep("    ", indent) .. "{")
	for k, v in pairs(T) do
		if (T == v) then
			print(string.rep("    ", indent) .. string.format("\t[%s] = \x1B[31m<recursion>\x1B[0m", formatprimative(k)))
		elseif (type(v) == "table") then
			if (displayed[v]) then
				print(string.rep("    ", indent) .. string.format("\t[%s] = \x1B[31m<recursion>\x1B[0m", formatprimative(k)))
			else
				displayed[v] = true
				print(string.rep("    ", indent) .. string.format("\t[%s] = {", formatprimative(k)))
				prettyPrintTable(v, indent + 2, displayed)
			end
		else
			print(string.rep("    ", indent) .. string.format("\t[%s] = %s", formatprimative(k), formatprimative(v)))
		end
	end
	print(string.rep("    ", indent) .. "}")
end

function printf(...)
	if #... == 1 then
		print(...)
	else
		print(string.format(...))
	end
end

function isType(v, t)
	return (type(v) == t) or ((type(v) == "table") and v.type == t)
end
---< End of Imports >---








VERSION = "0.1.0"
function Main()
	if (arg[1] == "-h" or arg[1] == "--help" or arg[1] == "-?" or arg[1] == nil) then
		print("Usage: disassembler.lua [options] file")
		print("Options:")
		print("\t--help\t\tDisplay this help message")
		print("\t--version\tDisplay version information")
		print("\t--entry <name>\tDefines entry point function")
		return
	end
	if (arg[1] == "--version") then
		print(string.format("disassembler.lua version %s\n%s", VERSION, _VERSION))
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
	if decompile(inputfile, getarg("--entry")) then
		return
	else
		print("Failed to disassemble")
	end
end

local function packOperandstoString(ops)
	s = ""
	for _, v in ipairs(ops) do
		v = v.value
		if (type(v) == "string") then
			s = s .. string.format("\"%s\", ", v)
		elseif (type(v) == "number") then
			s = s .. string.format("%d, ", v)
		elseif (type(v) == "table") then
			s = s .. "{"
			for i, vv in ipairs(v) do
				s = s .. string.format("%d, ", vv)
			end
			s = s .. "}, "
		end
	end
	return s
end
local function forEach(t, f)
	local r = {}
	for i, v in ipairs(t) do
		r[i] = f(v)
	end
	return r
end

local function stringToByteArray(s) 
	local t = {}
	for i = 1, #s do
		t[i] = s:byte(i)
	end
	return t
end


local function ifind(str)
	return function(s, i)
		local a, b = s:find(str, i)
		if (a) then
			return a, b
		end
		return nil
	end
end

function decompile(inputfile, entry)
	local h = io.open(inputfile, "rb")
	assert(h, "Could not open input file")
	local bytecode = h:read("all")
	h:close()
	local disassemblers = require("deinstructions")
	local pointer = 1
	if entry then
		local _, entry_pointer = bytecode:find("\x2A\x08" .. entry .. "\0" , pointer)
		if (not entry_pointer) then
			error(string.format("Entry point not found: \"%s\"", entry))
		end
		pointer = entry_pointer + 1
		program = {}
		while (true) do
			local success, instruction, length = pcall(disassemblers.DecodeInstruction, bytecode, pointer)
			if (not success) then
				printf("Error dissassembling %08x : %s", pointer-1, instruction)
				break
			end
			if (not instruction) then
				break
			end
			bytes = bytecode:sub(pointer, pointer + length - 1)
			program[#program+1] = {pointer, instruction, bytes}
			pointer = pointer + length
			if (instruction.name == "ret") then
				break
			end
		end
	else
		program = {}
		for _, v in ifind("\x2A")(bytecode) do
			local _, t, len, name = disassemblers.DecodeOperand(bytecode, v + 1)
			program[name] = {
				pointer = v + 1 + len,
			}
		end
	end
	for i, v in ipairs(program) do
		Hex = table.concat(forEach(stringToByteArray(v[3]), function(v) return string.format("%02X", v) end), " ")
		padding = string.rep(" ", 75 - #Hex)
		print(string.format("%08x | %s%s |  %s %s", v[1], Hex, padding, v[2].name, table.concat(forEach(v[2].operands, function(v) return formatprimative(v.value) end), ", ")))
	end
	return true
end

Main()