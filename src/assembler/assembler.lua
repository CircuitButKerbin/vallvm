local VERSION = "0.0.1"	
local inputDir = "./in"
local outputDir = "./out"
local parser = require("lib.parser")
local exception = require("lib.error")
require("lib.utilitys")
---returns a string with the type formatted with ANSI color codes;

local instructionLib = require("lib.instructions")


---comment
---@param assembly table<string|unfinishedassembly|table>
local function resolveLabels(assembly)
	local meta, bin = {labels={},references={}}, ""
	for i, v in ipairs(assembly) do
		if (type(v) == "table") then prettyPrintTable(v) else print(formatprimative(v)) end
		if (isType(v, "LabeledLine")) then
			for _, label in ipairs(v.labels) do
				meta.labels[label.name] = {offset=#bin, line=i}
			end
			bin = bin .. v.assembly
		elseif (isType(v, "UnfinishedAssembly")) then
			meta.references[v.referencedLabel] = {offset=#bin, line=i, is_relative=v.is_relative, asm=v.finish}
			bin = bin .. v.placeholder
		else
			bin = bin .. v
		end
	end
	return {assembly=bin, labels=meta.labels, references=meta.references}
end

local function assembleLabelReferences(program)
	for k, v in pairs(program.references) do
		local label = program.labels[k]
		if (not label) then
			Throw(exception.new("assembler.compiler.UnresolvedLabelException", string.format("Unresolved label %s", k)))
		end
		local offset, location, asm = label.offset, v.offset
		if (v.is_relative) then
			offset = offset - v.offset
		end
		asm = v.asm(offset)
		program.assembly = program.assembly:sub(1, location) .. asm .. program.assembly:sub(location + #asm + 1, #program.assembly)
	end
	return program.assembly
end
---@param parsed table<ParsedLine>
local function assembleParsed(parsed)
	local assembled = {}
	for i, line in ipairs(parsed) do
		---@type ParsedLine
		line = line;
		--#TODO refactor assembler stuffs
		assembled[#assembled+1] = #line.labels == 0 and instructionLib.assembleInstruction(line.instruction) or {assembly=instructionLib.assembleInstruction(line.instruction), labels=line.labels, type="LabeledLine"}
	end
	print("Resolving Labels")
	local pgm = assembleLabelReferences(resolveLabels(assembled))
	print("Finished Resolving Labels")
	return pgm
end
--- Function for calling stuff when ran with --debug_test
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
	prettyPrintTable(_G)
	h:close();
end


function Main()
	if (arg[1] == "-h" or arg[1] == "--help" or arg[1] == "-?" or arg[1] == nil) then
		print("Usage: assembler.lua [options] file")
		print("Options:")
		print("\t--help\t\tDisplay this help message")
		print("\t--version\tDisplay version information")
		print("\t-o <file>\tOutput to file")
		print("\t-O prints the output to stdout")
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
	local Parsed = Try({parser.parseVallASM, h:read("all"), {filename=inputfile:match(".*/(.*)")}}, function (e)
		prettyPrintTable(e)
		return true
	end, function ()
		h:close()
	end)
	local assembled = Try({assembleParsed,Parsed}, function(e)	
		e:caused(exception.new("assembler.compiler.AssemblyException", "Failed to assemble"))
		return
	end)
	if (not assembled) then
		print("failed to assemble")
		return
	end
	if (getarg("-O", true)) then
		print(formatprimative(assembled,true))
		return
	end
	h = io.open(outputfile, "wb")
	assert(h, "Could not open output file")
	h:write(assembled)
	h:close()
end


xpcall(Main, 
---@overload fun(e: Exception)
function(e)
	if (type(e) == "string") then
		print("\x1B[31mUnhandled Exception in Main\x1B[0m:")
		print(debug.traceback(e or "(error message was nil)"))
		return
	end
	prettyPrintTable(e)
	print("\x1B[31mUnhandled Exception in Main\x1B[0m:")
	while (e) do
		if (e.__parent) then
			print("Caused:  " .. e.type .. ": " .. e.message)
		else
			print("\t" .. e.type ..  ": " .. e.message)
		end
		
		e = e.__child
	end
	print(debug.traceback())
end)
