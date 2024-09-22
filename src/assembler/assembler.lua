local VERSION = "0.0.1"	
local inputDir = "./in"
local outputDir = "./out"
local parser = require("lib.parser")
local exception = require("lib.error")
require("lib.utilitys")
---returns a string with the type formatted with ANSI color codes;

local assemblers = require("instructions")

---@param parsed table<ParsedLine>
local function assembleParsed(parsed)
	local assembled = {}
	for i, line in ipairs(parsed) do
		---@type ParsedLine
		line = line;
		Assert(line.instruction, exception.new("assembler.compiler.AssemblyException", string.format("No instruction at line %d", line.lineDefined)))
		local assembler = assemblers[line.instruction.name:lower()]
		Assert(line.instruction, exception.new("assembler.compiler.AssemblyException", string.format("Invalid Instruction at line %d", line.lineDefined)))
		printf("\x1B[1AAssembling instruction %d/%d", i, #parsed)
		assembled[#assembled+1] = #line.labels == 0 and assembler(line.instruction) or {assembly=assembler(line.instruction), labels=line.labels, type="LabeledLine"}
	end
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
	for chunkToResolve, v in ipairs(chunks) do
		if (type(v) == "table" and (isType(v, "UnfinishedAssembly") or isType(v.assembly, "UnfinishedAssembly"))) then
			local assembly = v;
			if (isType(v.assembly, "UnfinishedAssembly")) then
				assembly = v.assembly
			end
			local key = v.key
			local found = false
			local labelOffset = 0
			for _, labelChunk in ipairs(chunks) do
				if (isType(labelChunk, "LabeledLine")) then
					for _, l in ipairs(labelChunk.labels) do
						if (l.name == key) then
							found = true
							break
						end
					end
					if (found) then
						local jloc
						if (v.unfinished:find("URELJ")) then
							jloc = labelOffset - start
						else
							jloc = labelOffset
						end
						local asm = v.unfinished:sub(1, 1) .. "\x02".. string.pack("i4", jloc)
						if (isType(v.assembly, "UnfinishedAssembly")) then
							chunks[chunkToResolve].assembly = asm
						else
							chunks[chunkToResolve] = asm
						end
						break
					end
				end
				labelOffset = labelOffset + (isType(labelChunk, "LabeledLine") and ((isType(labelChunk, "UnfinishedAssembly") and #labelChunk.assembly.unfinished) or #labelChunk.assembly) or ((isType(labelChunk, "UnfinishedAssembly") and #labelChunk.unfinished) or #labelChunk))
			end
			if (not found) then
				Throw(exception.new("assembler.compiler.UnresolvedLabelException", string.format("Unresolved label %s", key)))
			end
		end
		start = start +  (isType(v, "LabeledLine") and ((isType(v, "UnfinishedAssembly") and #v.assembly.unfinished) or #v.assembly) or ((isType(v, "UnfinishedAssembly") and #v.unfinished) or #v))
	end
	assembled = chunks
	chunks = {}
	print("Finished Resolving Labels")
	--prettyPrintTable(assembled)
	for i, v in ipairs(assembled) do
		if (type(v) == "string" or (isType(v,"LabeledLine") and type(v.assembly) == "string")) then
			chunk = chunk .. ((type(v) == "table" and v.assembly) or v)
		else
			Throw(exception.new("assembler.compiler.AssemblyException", string.format("Failed to resolve chunk %d (Missing label?)", i)))
		end
	end
	print("Finished Chunk Recompilation")
	return chunk
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