---@param v any value to format
---@param bin any 
---@return string
---@overload fun(v: string): string
function formatprimative(v, bin, noansi)
	local redish = (not noansi) and "\x1B[38;5;196m" or ""
	local orange = (not noansi) and "\x1B[38;5;136m" or ""
	local green = (not noansi) and "\x1B[38;5;2m" or ""
	local pink = (not noansi) and "\x1B[38;5;13m" or ""
	local reset = (not noansi) and "\x1B[0m" or ""
	if (type(v) == "string") then
		--check for binary
		if (v:match('[^ -~\n\t]')) then
			local esc = green .. "\"" .. reset
			esc = esc:gsub("\\", "\\\\")
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
	-- elseif (type(v) == "table") then
	-- 	print('no')
	-- 	return ("{" .. table.concat(forEach(v, function (k,v) return string.format("%s = %s", k, (type(v) ~= "table") and formatprimative(v, bin, noansi) or "\"{ ... }\"") end), ", ") .. "}")
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
--------


function forEach(t, f)
	local tmp, i  = {}, 1
	for k, v in pairs(t) do
		tmp[i] = f(k,v)
		i = i + 1
	end
	return tmp
end

function forI(s, n, f)
	local tmp= {}
	for i=s, n do
		tmp[i] = f(i)
	end 
	return tmp
end

local map = {
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
	[0x31] = "nop"
}

function printf(fmt, ...)
	print(string.format(fmt, ...))
end
---comment
---@param ... any
---@return any, integer
function unpack(...)
	if (...)[1] == "t" then
		-- #TODO unpack table

	elseif (...)[1] == "fn" then
		-- #TODO unpack fn

	else
		return string.unpack(...)
	end
end
local function trinary(c, a, b)
	if c then
		return a
	else
		return b
	end
end
local function inRange(v, a, b)
	return v >= a and v <= b
	
end
local function toBool(v)
	return v > 0
end

local function btoNumber(v)
	return v and 1 or 0
end
local function split(str, sep)
	local sep, fields = sep or ":", {}
	local pattern = string.format("([^%s]+)", sep)
	str:gsub(pattern, function(c) fields[#fields+1] = c end)
	return fields
end
local function resolveObject(path)
	if (path:match("%.")) then
		local path = split(path, "%.")
		local obj = ENV
		for i=1, #path do
			obj = obj[path[i]]
			if (not obj) then
				return nil
			end
		end
		return obj
	end
	return ENV[path]
end

---next points to the next unread byte 
---@param bin string 
---@param ptr integer
---@return integer next, any data  
local function parseDataType(bin, ptr, indexAsGlobal)
	local meta = bin:byte(ptr)
	local SI, isPointer, isRegister = meta & 0x1f, (meta & 0x20) > 0, (meta & 0x40) > 0
	if (isRegister) then
		return ptr + 1, _State.r[SI];
	end
	local next = ptr + 1
	local l
	if isPointer then
		ptr, next  = unpack("I2", bin, ptr)
	else
		ptr = next
	end
	local v, n
	if SI == 1 then
		v, n = unpack("i2", bin, ptr)
	elseif SI == 2 then
		-- i32
		v, n = unpack("i4", bin, ptr)
	elseif SI == 3 then
		-- f32
		v, n = unpack("f", bin, ptr)
	elseif SI == 8 then
		-- global
		v, n = unpack("z", bin, ptr)
		v = trinary(indexAsGlobal, _State.g[v], v)
	elseif SI == 5 then
		-- bytes
		v, n = unpack("s2", bin, ptr)
	elseif SI == 6 then
		-- table
		v, n = unpack("t", bin, ptr)
	elseif SI == 0 then
		-- nil
		v, n = nil, ptr
	elseif SI == 7 then
		-- function
		v, n = unpack("fn", bin, ptr)
	else
		print("[DEBUG] Unhandled SI: " .. SI)
		--#TODO: Throw
	end
	return trinary(isPointer, next, n), v
end
---comment
---@param bin any
---@param ptr any
---@return  number, function
local function writeDataType(bin, ptr)
	local meta = bin:byte(ptr)
	local SI, isPointer, isRegister = meta & 0x1f, (meta & 0x20) > 0, (meta & 0x40) > 0
	if (isRegister) then
		return ptr+1, function (v) _State.r[SI] = v end
	end

	if (SI == 8) then
		local k, n = unpack("z", bin, ptr+1)
		return n, function (v) _State.g[k] = v; end
	end
	if (SI == 5) then
		local k, n = unpack("s2", bin, ptr+1)
		return n, function (v) _State.g[k] = v;end
	end
end







_State = {
	ra_stack = {},
	_dst_stack= {},
	stack = {},
	program = "",
	ip = 0,
	g = {},
	r = forI(1, 32, function() return nil end),
	tick = function (self)
		--#region DEBUG
		assert(inRange(self.ip, 1, #self.program), "Instruction pointer out of bounds")
		--#endregion DEBUG
		local op = self.program:byte(self.ip)
		local stack, program, nextip, data, write, yield = self.stack, self.program, 0, nil, nil, false
		--#region DEBUG
		assert(map[op], "Invalid opcode")
		--#endregion DEBUG
		if op == 1 then
			nextip, data = parseDataType(program, self.ip+1, true)
			push(data)
		elseif op == 2 then
			nextip, write = writeDataType(program, self.ip+1)
			write(pop())
		-- elseif op == 0x0B then
		-- 	push(~pop())
		elseif inRange(op, 3, 0x15) then
			local a, b = pop(), pop()
			nextip = self.ip + 1
			if (op==3) then
				push(a + b)
			elseif (op==4) then
				push(a - b)
			elseif (op==5) then
				push(a * b)
			elseif (op==6) then
				push(a / b)
			elseif (op==7) then
				push(a % b)
			elseif (op==8) then
				push(a & b)
			elseif (op==9) then
				push(a | b)
			elseif (op==0xA) then
				push(a ~ b)
			elseif (op==0xC) then
				push(a << b)
			elseif (op==0xD) then
				push(a >> b)
			elseif (op==0x10) then
				push(a == b)
			elseif (op==0x11) then
				push(a ~= b)
			elseif (op==0x12) then
				push(a < b)
			elseif (op==0x13) then
				push(a > b)
			elseif (op==0x14) then
				push(a <= b)
			elseif (op==0x15) then
				push(a >= b)
			end
		elseif op==0x16 then
			nextip, data = parseDataType(program, self.ip+1)
			--print(string.format("[DEBUG] \t |-LOAD %s -> %s", data, _State.g[data]))
			push(_State.g[data])
		elseif op==0x17 then
			nextip, write = writeDataType(program, self.ip+1)
			write(peek())
		elseif op==0x18 then
			nextip, data = parseDataType(program, self.ip+1, true)
			nextip, write = writeDataType(program, nextip)
			write(data)
		elseif op==0x19 then
			swap()
			nextip = self.ip + 1
		elseif op==0x1A then
			dupe()
			nextip = self.ip + 1
		elseif op==0x1B then
			pop()
			nextip = self.ip + 1
		elseif op==0x1C then
			over()
			nextip = self.ip + 1
		elseif op==0x20 then
			nextip, data = parseDataType(program, self.ip+1)
			self.ra_stack[#self.ra_stack+1] = nextip
			_, self.ip = program:find("\x2A\x08" .. data .. "\0")
			self._dst_stack[#self._dst_stack+1] = {data, self.ip}
		elseif op == 0x21 then
			if #self.ra_stack == 0 then
				return true
			else
				self.ip = table.remove(self.ra_stack)
				table.remove(self._dst_stack)
			end
		elseif inRange(op, 0x22, 0x27) then
			nextip, data = parseDataType(program, self.ip+1)
			local stackState = pop()
			if (type(stackState)) == "number" then
				stackState = toBool(stackState)
			end
			local cond = (op == 0x22 or op == 0x25) or ((op == 0x23 or op == 0x26) and stackState) or ((op == 0x24 or op == 0x27) and not stackState)
			if cond then
				nextip = trinary(op>=0x25, self.ip + data, data)
			end
		elseif op==0x28 then
			nextip, data = parseDataType(program, self.ip+1)
			local args, returns;
			nextip, args = parseDataType(program, nextip)
			nextip, returns = parseDataType(program, nextip)
			args = pull(args)
			data = table.pack(resolveObject(data)(table.unpack(args)))
			for i=1, returns do
				push(data[i])
			end
		elseif op==0x29 then
			yield = true
			nextip = self.ip + 1
		elseif op==0x2A or op==0x31 or op==0x30 then
			nextip = self.ip + 1
		end
		self.ip = nextip
		return yield
	end
}

--#region Stack_wrap
local stk = _State.stack
---@diagnostic disable-next-line
pop, push, cut, pull, peek, swap, dupe, over = function()
	assert(#stk == 0, "Stack underflow")
	local v = stk[#stk]
	stk[#stk] = nil
	return v
end,
function(v)
	stk[#stk+1] = v
end,
function(n)
	assert(#stk >= n "Stack underflow")
	for i=1, n do
		stk[#stk] = nil
	end
end,
function(n)
	local t = {}
	assert(#stk >= n, "Stack underflow")
	for i=0, n-1 do
		t[n-i] = stk[#stk]
		stk[#stk] = nil
	end
	return t
end,
function()
	return stk[#stk]
end,
function()
	stk[#stk-1], stk[#stk] = stk[#stk], stk[#stk-1]
end,
function()
	stk[#stk+1] = stk[#stk]
end,
function()
	stk[#stk+1] = stk[#stk-1]
end
--#endregion Stack_wrap
Debug_breakpoints = {
}

--#region DEBUG
PausedByBP = false
---@param ip integer
---@return boolean next_bp
function Debug_Check_BP(ip)
	if Debug_breakpoints[ip] then
		local bp = Debug_breakpoints[ip]
		if type(bp) == "function" then -- conditonal breakpoint
			return bp()
		else -- regular breakpoint
			return true
		end
	end
	return false
end

function Debug__tick() 
	if not PausedByBP and Debug_Check_BP(_State.ip) then
		---#TODO: Emit BP event
		print(string.format("Hit breakpoint @ %08x", _State.ip))
		PausedByBP = true
		return true
	end
	PausedByBP = false
	local succ, msg = pcall(_State.tick, _State)
	if not succ then
		error(string.format("%08x | %s threw %s", _State.ip or 0xDEADBEEF, map[_State.program:byte(_State.ip)] or "???", msg))
	end
	return false
end

function Debug_step()
	Debug__tick()
end

function Debug_continue()
	while not Debug__tick() do end
end

function Debug_stepIn()

end

function DebugMain()
	DAPProvider = require('src.debugger.DAPProvider')
	local session = DAPProvider.CreateDAPSession(DAPProvider.Socket.bind("127.0.0.1:40621"):accept())
	---@alias DAPRequestCallback fun(request: DAP_Request): DAP_Response
	
	---@type DAPRequestCallback
	local function initializeRequestCallback(req)
		---@type DAP_Response
		return {
			type='response',
			seq=0,
			success=true,
			command='initialize',
			request_seq=req.seq,
			body = {
				supportsConfigurationDoneRequest	  = true,
				supportsFunctionBreakpoints			  = true,
				supportsConditionalBreakpoints		  = true,
				-- supportsHitConditionalBreakpoints	  = true,
				-- supportsEvaluateForHovers			  = true,
				-- exceptionBreakpointFilters			  = true,
				-- supportsStepBack					  = true,
				-- supportsSetVariable					  = true,
				-- supportsRestartFrame				  = true,
				-- supportsGotoTargetsRequest			  = true,
				-- supportsStepInTargetsRequest		  = true,
				-- supportsCompletionsRequest			  = true,
				-- completionTriggerCharacters			  = {},
				-- supportsModulesRequest				  = true,
				-- additionalModuleColumns				  = true,
				-- supportedChecksumAlgorithms			  = {},
				supportsRestartRequest				  = true,
				-- supportsExceptionOptions			  = true,
				-- supportsValueFormattingOptions		  = true,
				supportsExceptionInfoRequest		  = true,
				supportTerminateDebuggee			  = true,
				supportSuspendDebuggee				  = true,
				-- supportsDelayedStackTraceLoading	  = true,
				supportsLoadedSourcesRequest		  = true,
				supportsLogPoints					  = true,
				supportsVariableType				  = true,
				-- supportsTerminateThreadsRequest		  = true,
				-- supportsSetExpression				  = true,
				supportsTerminateRequest			  = true,
				supportsDataBreakpoints				  = true,
				-- supportsReadMemoryRequest			  = true,
				-- supportsWriteMemoryRequest			  = true,
				supportsDisassembleRequest			  = true,
				supportsCancelRequest 				  = true,
				supportsBreakpointLocationsRequest	  = true,
				-- supportsClipboardContext 			  = true,
				supportsSteppingGranularity			  = true,
				supportsInstructionBreakpoints		  = true,
				-- supportsExceptionFilterOptions		  = true,
				supportsSingleThreadExecutionRequests = true,
				supportsDataBreakpointBytes			  = true,
				--breakpointModes						  = {},
				supportsANSIStyling					  = true,		
			}
		}
	end

	Status = {
		launched = false,
		debuggee = {
			name = "",
			source = "",
			sourcePath = "",
			hasSource = false,
			binary = "",
			binaryPath = "",
			hasSymbols = false,
			symbols = {},
			symbolsPath = "",
			exceptionInfo = {},
			pausedOnException = false,
			state = "stopped"
		}
	}

	---@type DAPRequestCallback
	local function configurationDoneRequestCallback(req)
		---@type DAP_Response
		return {
			type='response',
			seq=0,
			success=true,
			command='configurationDone',
			request_seq=req.seq,
		}
	end

	---@type DAPRequestCallback
	local function launchRequestCallback(req)
		if Status.launched then
			---@type DAP_ErrorResponse
			return {
				type='response',
				seq=0,
				success=false,
				command='launch',
				request_seq=req.seq,
				body = {
					id=2,
					format="Target already running..."
				}
			}
		end
		if not req.arguments.program then
			---@type DAP_ErrorResponse
			return {
				type='response',
				seq=0,
				success=false,
				command='launch',
				request_seq=req.seq,
				body = {
					id=3,
					format="Target not provided."
				}
			}
		end
		local path, file_ext, file, ext = req.arguments.program:match("(.-)(([^\\]-).([^%.]+))$")
		Status.debuggee.name = file
		if ext == "vallasm" or ext == "vsm" then
			--load source
			local FILE = io.open(req.arguments.program, "r")
			if not FILE then
				DAPProvider.Log("Could not find source file.")
			else
				DAPProvider.Log("Loaded source file.")
				Status.debuggee.source = FILE:read("all")
				Status.debuggee.sourcePath = req.arguments.program
				Status.debuggee.hasSource = true
				FILE:close()
			end
			DAPProvider.Log("Target is vsm.")
			--try to locate .vdb
			local vdb = path .. file .. ".vdb"
			local FILE = io.open(vdb, "r")
			if not FILE then
				-- no VDB
				DAPProvider.Log("No VDB found for target.")
				Status.debuggee.hasSymbols = false
			else
				DAPProvider.Log(string.format("Found VDB for target @ \'%s\'", vdb))
				local maps = {}
				for l in FILE:lines() do
					local n, a = l:match("([a-zA-Z0-9]+)@([a-fA-F0-9]+)")
					maps[tonumber(a, 16) + 1] = tonumber(n)
				end
				DAPProvider.Log(string.format("Loaded %d symbols", #maps))
				Status.debuggee.hasSymbols = true
				Status.debuggee.symbols = maps
				Status.debuggee.symbolsPath = vdb
			end
			-- find binary
			local bin = path .. file .. ".val"
			FILE = io.open(bin, "rb")
			if not FILE then
				---@type DAP_ErrorResponse
				return {
					type='response',
					seq=0,
					success=false,
					command='launch',
					request_seq=req.seq,
					body = {
						id=4,
						format="Could not find target assembly."
					}
				}
			end
			Status.debuggee.binaryPath = bin
			Status.debuggee.binary = FILE:read("all")
		end
		_State.program = Status.debuggee.binary
		_, _State.ip = _State.program:find(string.format("\x2A\x08%s", req.arguments.entry or 'init') .. '\0')
		_State.ip = _State.ip + 1
		DAPProvider.Log(string.format("Launched target: Entry @ %08x", _State.ip))
		session:emitEvent(
			---@type DAP_Event
			{
				type='event',
				event='process',
				seq = 0,
				body = {
					name = req.arguments.target or '(unknown)',
					isLocalProcess = true,
					startMethod = 'launch',
					pointerSize = 32
				}
			}
		)
		session:emitEvent(
			---@type DAP_Event
			{
				type='event',
				event='stopped',
				seq=0,
				body = {
					reason='entry',
					threadId = 1,
					description= "Paused on entry.",
					allThreadsStopped=true
				}
			}
		)
		Status.launched = true;
		---@type DAP_Response
		return {
			type='response',
			seq=0,
			success=true,
			command='launch',
			request_seq=req.seq,
		}
	end

	---@type DAPRequestCallback
	local function attachRequestCallback(req)
		---@type DAP_ErrorResponse
		return {
			type='response',
			seq=0,
			success=false,
			command='attach',
			body={
				id=1,
				format="Attach not supported."
			},
			request_seq=req.seq
		}
	end

	---@type DAPRequestCallback
	local function scopesRequestCallback(req)
		---#TODO verify session active
		---@type DAP_Response
		return {
			type='response',
			seq=0,
			success=true,
			command='scopes',
			body = {
				scopes = {
					{
						name="Globals",
						variablesReference=0,
						namedVariables=#_State.g,
						expensive=false,
						--source
					},
					{
						name="Registers",
						variablesReference=1,
						indexedVariables=#_State.r
					},
					{
						name="Stack",
						variablesReference=2,
						indexedVariables=#_State.stack
					}
				}
			},
			request_seq=req.seq
		}
	end

	---@type DAPRequestCallback
	local function variablesRequestCallback(req)
		local variables = {}
		if req.arguments.variablesReference == 0 then
			for k, v in pairs(_State.g) do
				variables[#variables+1] = {
					name=k,
					value=tostring(v),
					variablesReference=0
				}
			end
		elseif req.arguments.variablesReference == 1 then
			for k, v in pairs(_State.r) do
				variables[#variables+1] = {
					name=k,
					value=tostring(v),
					variablesReference=0
				}
			end
		elseif req.arguments.variablesReference == 2 then
			for i=1, #_State.stack do
				variables[#variables+1] = {
					name=string.format("Stack[%d]", i),
					value=tostring(_State.stack[i]),
					variablesReference=0
				}
			end
		end
		---@type DAP_Response
		return {
			type='response',
			seq=0,
			success=true,
			command='variables',
			body = {
				variables = #variables == 0 and "\xff" or variables
			},
			request_seq=req.seq
		}
	end

	---@type DAPRequestCallback
	local function sourceRequestCallback(req)
		local t, c;
		if Status.debuggee.hasSource then
			t = "text/x-vallasm"
			c = Status.debuggee.source
		else
			t = "text/plain"
			c = "No source available."
		end
		---@type DAP_Response
		return {
			type ='response',
			seq=0,
			success=true,
			command='source',
			request_seq=req.seq,
			body = {
				---#TODO attempt to get src
				content = c;
				mimeType = t;
			}
		}
	end

	---@type DAPRequestCallback
	local function stackTraceRequestCallback(req)
		local body = {
			stackFrames = {
				{
					id = 0,
					name = "IP<>",
					line=0,
					column=0
				}
			},
			totalFrames = 1,
		}
		if Status.debuggee.hasSource and Status.debuggee.hasSymbols then
			body.stackFrames[1].line = Status.debuggee.symbols[_State.ip] or 0
			if not Status.debuggee.symbols[_State.ip] then
				DAPProvider.Log(string.format("Could not find symbol for %08x", _State.ip), 1)
			end
			body.stackFrames[1].source = {
				name = Status.debuggee.name,
				path = Status.debuggee.sourcePath:gsub("\\", "/"),
				sourceReference = 0
			}
		end
		---@type DAP_Response
		return {
			type='response',
			seq=0,
			success=true,
			command='stackTrace',
			request_seq=req.seq,
			body = body;
		}
	end

	local function threadsRequestCallback(req)
		---@type DAP_Response
		return {
			type='response',
			seq=0,
			success=true,
			command='threads',
			request_seq=req.seq,
			body = {
				threads = {
					{
						id=1,
						name="Main Thread"
					}
				}
			}
		}
	end

	local function terminateRequestCallback(req)
		---@type DAP_Response
		return {
			type='response',
			seq=0,
			success=true,
			command='terminate',
			request_seq=req.seq,
		}
	end
	local function disconnectRequestCallback(req)
		---@type DAP_Response
		return {
			type='response',
			seq=0,
			success=true,
			command='disconnect',
			request_seq=req.seq,
		}
	end
	local function wompHandler()
		session:emitEvent(
			---@type DAP_Event
			{
				type='event',
				event='terminated',
				seq=0,
			}
		)
		session:emitEvent(
			---@type DAP_Event
			{
				type='event',
				event='exited',
				seq=0,
				body = {
					exitCode = -1073741819
				}
			}
		)
		DAPProvider.Log("Target exited with code -1073741819")
		session:close()
	end
	local function nextRequestCallback(req)
		if Status.debuggee.pausedOnException then
			wompHandler()
		end
		local stepped, msg = pcall(Debug_step)
		if stepped then
			session:emitEvent(
				---@type DAP_Event
				{
					type='event',
					event='stopped',
					seq=0,
					body = {
						reason='step',
						threadId = 1,
						description= "Paused on next.",
						allThreadsStopped=true
					}
				}
			)
		else
			session:emitEvent(
				---@type DAP_Event
				{
					type='event',
					event='stopped',
					seq=0,
					body = {
						reason='exception',
						threadId = 1,
						description= "Paused on exceoption.",
						allThreadsStopped=true
					}
				}
			)
			Status.debuggee.pausedOnException = true
			Status.debuggee.exceptionInfo = {
				exceptionId = msg,
				description = msg,
				breakMode = "always"
			}
		end
		---@type DAP_Response
		return {
			type='response',
			seq=0,
			success=true,
			command='next',
			request_seq=req.seq,
		}
	end
	---@type DAPRequestCallback
	local function exceptionInfoRequestCallback(req)
		if Status.debuggee.pausedOnException then
			return {
				type='response',
				seq=0,
				success=true,
				command='exceptionInfo',
				request_seq=req.seq,
				body = {
					exceptionIdid=Status.debuggee.exceptionInfo.exceptionId,
					description=Status.debuggee.exceptionInfo.description,
					breakMode=Status.debuggee.exceptionInfo.breakMode
				}
			}
		else
			return { 
				type='response',
				seq=0,
				success=false,
				command='exceptionInfo',
				request_seq=req.seq,
				body = {
					id=10,
					format="No exception."
				}
			}
		end
	end
	---@type DAPRequestCallback
	local function continueRequestCallback(req)
		if Status.debuggee.pausedOnException then
			wompHandler()
		else
			Status.debuggee.state = "running"
			return {
				type='response',
				seq=0,
				success=true,
				command='continue',
				request_seq=req.seq,
				body = {
					allThreadsContinued=true
				}
			}
		end
		error("unreachable")
	end
	
	session:registerRequestCallback('initialize', initializeRequestCallback)
	session:registerRequestCallback('launch', launchRequestCallback)
	session:registerRequestCallback('configurationDone', configurationDoneRequestCallback)
	session:registerRequestCallback('attach', attachRequestCallback)
	session:registerRequestCallback('scopes', scopesRequestCallback)
	session:registerRequestCallback('variables', variablesRequestCallback)
	session:registerRequestCallback('source', sourceRequestCallback)
	session:registerRequestCallback('stackTrace', stackTraceRequestCallback)
	session:registerRequestCallback('threads', threadsRequestCallback)
	session:registerRequestCallback('terminate', terminateRequestCallback)
	session:registerRequestCallback('disconnect', disconnectRequestCallback)
	session:registerRequestCallback('next', nextRequestCallback)
	session:registerRequestCallback('continue', continueRequestCallback)
	session:registerRequestCallback('exceptionInfo', exceptionInfoRequestCallback)
	while session:update() do
		if Status.debuggee.state == "running" then
			local stepped, msg = pcall(Debug_step)
			if not stepped then
				Status.debuggee.state = "stopped"
				session:emitEvent(
					---@type DAP_Event
					{
						type='event',
						event='stopped',
						seq=0,
						body = {
							reason='exception',
							threadId = 1,
							description= "Paused on exceoption.",
							allThreadsStopped=true
						}
					}
				)
				Status.debuggee.pausedOnException = true
				Status.debuggee.exceptionInfo = {
					exceptionId = msg,
					description = msg,
					breakMode = "always"
				}
			end
		end
	end
end


--#endregion DEBUG

local minMap = {
	["P"] = "program",
	["S"] = "stack",
	["B"] = "r",
	["K"] = "ip",
	["G"] = "g",
	["R"] = "ra_stack",
}

_State = setmetatable(_State, {
	__index = function (t, k)
		if (minMap[k]) then
			return rawget(t, minMap[k])
		end
		return rawget(t, k)
	end
})


ENV = {
	State = function () return _State end,
	concat = function(a, b) return a..b end,
	len = function(t) return #t end,
	newT = function() return {} end,
	get = function(t, k) return t[k] end,
	string = string,
	screen = {
		drawText = function (x, y, text)
			print(string.format("[DEBUG] drawText(%d, %d, %s)", x, y, text))
		end,
	}
}


DebugMain()

