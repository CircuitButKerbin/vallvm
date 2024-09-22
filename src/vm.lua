local processor_state = {
	ticks = 0;
	init = false,
	stack = {},
	register = {},
	program_counter = 1,
	program = "\x21\x2A\x08\x69\x6E\x69\x74\x00\x01\x05\x0D\x00\x48\x65\x6C\x6C\x6F\x2C\x20\x77\x6F\x72\x6C\x64\x21\x28\x08\x70\x72\x69\x6E\x74\x00\x01\x01\x00\x01\x00\x00\x21\x2A\x08\x6F\x6E\x54\x69\x63\x6B\x00\x01\x01\x01\x00\x28\x08\x67\x65\x74\x42\x6F\x6F\x6C\x00\x01\x01\x00\x01\x01\x00\x27\x02\x2F\x00\x00\x00\x01\x05\x17\x00\x54\x68\x65\x20\x73\x63\x72\x65\x65\x6E\x20\x77\x61\x73\x20\x74\x6F\x75\x63\x68\x65\x64\x21\x28\x08\x70\x72\x69\x6E\x74\x00\x01\x01\x00\x01\x00\x00\x01\x05\x19\x00\x54\x68\x65\x20\x73\x63\x72\x65\x65\x6E\x20\x77\x61\x73\x6E\x27\x74\x20\x74\x6F\x75\x63\x68\x65\x64\x28\x08\x70\x72\x69\x6E\x74\x00\x01\x01\x00\x01\x00\x00\x01\x05\x0A\x00\x4C\x6F\x6F\x70\x20\x74\x65\x73\x74\x3A\x28\x08\x70\x72\x69\x6E\x74\x00\x01\x01\x00\x01\x00\x00\x01\x01\x01\x00\x17\x08\x58\x00\x01\x01\x01\x00\x16\x08\x58\x00\x03\x17\x08\x58\x00\x01\x05\x11\x00\x4C\x6F\x6F\x70\x20\x69\x74\x65\x72\x61\x74\x69\x6F\x6E\x20\x25\x64\x16\x08\x58\x00\x28\x08\x73\x74\x72\x69\x6E\x67\x2E\x66\x6F\x72\x6D\x61\x74\x00\x01\x02\x00\x01\x01\x00\x28\x08\x70\x72\x69\x6E\x74\x00\x01\x01\x00\x01\x00\x00\x01\x01\x0A\x00\x16\x08\x58\x00\x12\x26\x02\xAD\xFF\xFF\xFF\x21",
	globals = {},
	functions = {},
	return_address_stack = {},
	cycles = 0,
}

local _procDebug = {
	trace = {},
	pushToExecTrace = function (s, instructionName, address)
		s.trace[address] = fmt("t+%d c+%d | %s ", processor_state.ticks, processor_state.cycles, instructionName)
	end,
	dumpProgram = function (highlight_location, highlight_length)
		local program = processor_state.program
		local buffer = ""
		local asciirep = ""
		local function buf(s) buffer = buffer .. s end
		for i = 1, #program do
			if (i % 16 == 1) then
				buf(fmt("%08X | ", i-1))
			end
			if (i == highlight_location) then
				buf(fmt("\x1B[31m%02X", string.byte(program, i)) .. (highlight_length==1 and "\x1B[0m" or ""))
				asciirep = asciirep .. "\x1B[31m".. string.char(string.byte(program, i)):gsub("[^ -~]", ".") .. (highlight_length==1 and "\x1B[0m" or "")
			elseif (i == highlight_location + highlight_length) then
				buf(fmt("\x1B[0m%02X", string.byte(program, i)))
				asciirep = asciirep .. "\x1B[0m".. string.char(string.byte(program, i)):gsub("[^ -~]", ".")
			else
				buf(fmt("%02X", string.byte(program, i)))
				asciirep = asciirep .. string.char(string.byte(program, i)):gsub("[^ -~]", ".")
			end
			if (i % 16 == 0) then
				buf(" | ")
				buf(asciirep) --replace non-printable characters with dots
				buf("\n")
				asciirep = ""
			else
				buf(" ")
			end
			if (i == #program) then
				local remaining = 16 - (#program % 16)
				buf(string.rep("   ", remaining))
				buf("| ")
				buf(asciirep)
				buf("\n")
			end
		end
		print(buffer)
	end
}


local function ResolveGlobalExtern(externName)
	local function split(str, sep)
		local sep, fields = sep or ":", {}
		local pattern = string.format("([^%s]+)", sep)
		str:gsub(pattern, function(c) fields[#fields+1] = c end)
		return fields
	end
	if (externName:match("%.")) then
		local path = split(externName, "%.")
		local obj = _ENV
		for i=1, #path do
			obj = obj[path[i]]
			if (not obj) then
				return nil
			end
		end
		return obj
	end
	return _ENV[externName]
end

---@enum OperandType


---@diagnostic disable-next-line
function onTick()
	--#TODO load program code
	ExecuteBytecode(processor_state.program, processor_state, "init", true)
	ExecuteBytecode(processor_state.program, processor_state, "onTick", true)
	ExecuteBytecode(processor_state.program, processor_state, "onTick", true)
	print("Ticks: " .. processor_state.ticks)
end

---@diagnostic disable-next-line
function onDraw()

end

function fmt(...)
	return string.format(...)
end

function ExecuteBytecode(bytecode, state, executeFunction, runProctected)
	function cut(t, count)
		for i=1, count do
			table.remove(t, #t)
		end
	end
	function pull(count, ...)
		return table.unpack(table.pack(...), 1, count);
	end
	function put(...)
		for i, v in ipairs({...}) do
			state.stack[#state.stack+1] = v
		end
	end
	function RegisterFunctions(bytecode)
		local functions = {}
		local i = 0
		while string.find(bytecode, "\x2A", i) do
			local definitionLocation = string.find(bytecode, "\x2A", i) + 1
			i = definitionLocation
			local _, t, len, name = ParseOperand(bytecode, i)
			assert(t == 8, fmt("Function names must be of variable type %d", t))
			assert(name, fmt("Function name must not be nil"))	
			i = i + len
			functions[name] = {
				pointer = i,
			}
		end
		state.functions = functions;
	end
	---@return any value, number type, integer size
	function ParseOperand(bytecode, location)
		local typeDef = string.byte(bytecode, location)
		local Type = typeDef & 0x1F
		if (Type == 0) then
			return nil, 0, 1
		end
		if (typeDef & 0x40 == 1) then
			return state.register[typeDef & 0x1F], 9, 1
		end
		if (typeDef & 0x20 == 1) then
			---#TODO
		end
		if (Type <= 3) then
			return string.unpack(Type==3 and "f" or fmt("i%d", Type*2), bytecode, location+1), Type, Type==1 and 3 or 5
		end
		if (Type == 5) then
			local len = string.unpack("i2", bytecode, location+1)
			return string.sub(bytecode, location+3, location+2+len), 5, len+3
		end
		if (Type == 6) then
			---#TODO table loading
		end
		if (Type == 7) then
			---#TODO function loading
		end
		if (Type == 8) then
			--null terminated var name
			local str = string.unpack("z", bytecode, location+1)
			return state.globals[str], 8, #str + 2, str
		end
		error(fmt("Unknown operand type %d [PC:%08x]", Type, state.program_counter or 0xDEADBEEF))
	end
	function WriteOperand(v, t, _, n)
		if (t == 8) then
			state.globals[n] = v
			return
		end
		if (t == 9) then
			state.register[n] = v
			return
		end
		error(fmt("Attempted to write to operand %d [PC:%08x]", t, state.program_counter or 0xDEADBEEF))
	end
	function ExecuteInstruction(bytecode, location, exitOnReturn)
		processor_state.cycles = processor_state.cycles + 1
		local op = string.byte(bytecode, location)
		if (op==1) then -- PUSH
			_procDebug:pushToExecTrace("PUSH", location)
			local v, t, len = ParseOperand(bytecode, location+1)
			put(v)
			state.program_counter = location + 1 + len
		elseif (op==2) then -- POP
			_procDebug:pushToExecTrace("POP", location)
			local v, t, len, n = ParseOperand(bytecode, location+1)
			WriteOperand(table.remove(state.stack), t, len, n)
			state.program_counter = location + 1 + len
		elseif (op==11) then -- ADD
			_procDebug:pushToExecTrace("ADD", location)
			state.stack[#state.stack] = ~state.stack[#state.stack]
			state.program_counter = location + 1
		elseif (3<=op and op<=0x15) then -- ADD, SUB, MUL, DIV, MOD, AND, OR, XOR, SHL, SHR, EQ, NEQ, LT, GT, LE, GE
			local a, b = state.stack[#state.stack], state.stack[#state.stack-1]
			cut(state.stack, 2)
			if (op==3) then
				_procDebug:pushToExecTrace("ADD", location)
				put(a + b)
			elseif (op==4) then
				_procDebug:pushToExecTrace("SUB", location)
				put(a - b)
			elseif (op==5) then
				_procDebug:pushToExecTrace("MUL", location)
				put(a * b)
			elseif (op==6) then
				_procDebug:pushToExecTrace("DIV", location)
				put(a / b)
			elseif (op==7) then
				_procDebug:pushToExecTrace("MOD", location)
				put(a % b)
			elseif (op==8) then
				_procDebug:pushToExecTrace("AND", location)
				put(a & b)
			elseif (op==9) then
				_procDebug:pushToExecTrace("OR", location)
				put(a | b)
			elseif (op==0xA) then -- 0x0A
				_procDebug:pushToExecTrace("XOR", location)
				put(a ~ b)
			elseif (op==0xC) then -- 0x0C
				_procDebug:pushToExecTrace("SHL", location)
				put(a << b)
			elseif (op==0xD) then -- 0x0D
				_procDebug:pushToExecTrace("SHR", location)
				put(a >> b)
			elseif (op==0x10) then -- 0x0E
				_procDebug:pushToExecTrace("EQ", location)
				put(a == b)
			elseif (op==0x11) then -- 0x0F
				_procDebug:pushToExecTrace("NEQ", location)
				put(a ~= b)
			elseif (op==0x12) then -- 0x10
				_procDebug:pushToExecTrace("LT", location)	
				put(a < b)
			elseif (op==0x13) then -- 0x11
				_procDebug:pushToExecTrace("GT", location)
				put(a > b)
			elseif (op==0x14) then -- 0x12
				_procDebug:pushToExecTrace("LE", location)
				put(a <= b)
			elseif (op==0x15) then -- 0x13
				_procDebug:pushToExecTrace("GE", location)
				put(a >= b)
			end
			state.program_counter = location + 1
		elseif (op==0x16) then -- LOAD
			_procDebug:pushToExecTrace("LOAD", location)
			local v, t, len, n = ParseOperand(bytecode, location+1)
			put(v)
			state.program_counter = location + len + 1
		elseif (op==0x17) then -- STORE
			_procDebug:pushToExecTrace("STORE", location)
			local v, t, len, n = ParseOperand(bytecode, location+1)
			assert(t == 8 or t==9, fmt("Store requires a global variable name or register, got type %d", t))
			WriteOperand(table.remove(state.stack, #state.stack), t, _, n)
			state.program_counter = location + len + 1
		elseif (op==0x18) then -- MOVE
			_procDebug:pushToExecTrace("MOVE", location)
			local v1, t1, len, n1 = ParseOperand(bytecode, location+1)
			local v2, t2, len2, n2 = ParseOperand(bytecode, location+1 + len)
			assert(t1 == 8 or t1==9 and t2 == 8 or t2 == 9, fmt("Move requires a global variable name or register, got type %d", t1))
			WriteOperand(v2, t1, len2, n1)
			state.program_counter = location + 1 + len + len2
		elseif (op==0x20) then -- CALL
			_procDebug:pushToExecTrace("CALL", location)
			local _, t, len, n = ParseOperand(bytecode, location+1)
			assert(t == 8, fmt("Call requires a variable name, got type %d", t))
			assert(state.functions[n], fmt("Function %s not found", n))
			state.return_address_stack[#state.return_address_stack+1] = state.program_counter
			state.program_counter = state.functions[n].pointer
		elseif (op==0x21) then -- RET
			_procDebug:pushToExecTrace("RET" .. (exitOnReturn and " [#]" or ""), location)
			if (exitOnReturn) then
				return true
			end
			state.program_counter = state.return_address_stack[#state.return_address_stack]
			cut(state.return_address_stack, 1)
		elseif (op >= 0x22 and op <= 0x27) then -- JUMP, JUMP_IF_TRUE, JUMP_IF_FALSE
			_procDebug:pushToExecTrace("JUMP", location)
			local v, t, len = ParseOperand(bytecode, location+1)
			assert(t == 1 or t == 2, fmt("Jumps requires a i32 or i16, got type %d", t))
			local stackState = table.remove(state.stack, #state.stack)
			local cond = (op == 0x22 or op == 0x25) or ((op == 0x23 or op == 0x26) and stackState) or ((op == 0x24 or op == 0x27) and not stackState)
			cut(state.stack, 1)
			if (cond) then
				state.program_counter = (op>=0x25 and (state.program_counter + v) or v)
			else
				state.program_counter = state.program_counter + len + 1
			end
		elseif (op==0x28) then -- INVOKE
			_procDebug:pushToExecTrace("INVOKE", location)
			local _, t, len, externName = ParseOperand(bytecode, location+1)
			assert(t == 8, fmt("invoke requires a variable name, got type %d", t))
			local fn = ResolveGlobalExtern(externName)
			assert(fn, fmt("Extern function %s not found", externName))
			local argCount, t, len2 = ParseOperand(bytecode, location + 1 + len)
			assert(t == 1 or t == 2, fmt("Extern function argument count must be of integer type %d", t))
			local args = {}
			for i=1, argCount do
				args[i] = state.stack[#state.stack - argCount + i]
			end
			cut(state.stack, argCount)
			local ret = table.pack(fn(table.unpack(args)))
			local returns, t, len3 = ParseOperand(bytecode, location+1 + len + len2)
			assert(t == 1 or t == 2, fmt("Extern function return count must be of integer type %d", t))
			for i=1, returns do
				put(ret[i])
			end
			state.program_counter = location + 1 + len + len2 + len3
		elseif (op==0x29) then -- YIELD
			_procDebug:pushToExecTrace("YIELD [#]", location)
			return true
		--elseif (op==0x2A) then
		--	_procDebug:pushToExecTrace("FNDEF")
		else
			error(fmt("Unknown opcode 0x%02X [PC:%08x]", op, state.program_counter or 0xDEADBEEF))
		end
	end
	if (not state.init) then
		RegisterFunctions(bytecode)
		state.init = true
	end
	if (executeFunction) then
		if (state.functions[executeFunction]) then
			state.program_counter = state.functions[executeFunction].pointer
		else
			error(fmt("Function %s not found", executeFunction))
		end
	end
	while true do
		local opcode = string.byte(bytecode, state.program_counter)
		local yielded;
		if (runProctected) then 
			local safe_counter = state.program_counter
			local suc, ret = pcall(ExecuteInstruction, bytecode, state.program_counter, executeFunction ~= nil)
			if (suc) then
				if (state.program_counter > #state.program) then
					suc = false
					ret = "PC jumped out of bounds after executing instruction"
				end
			end
			if (not suc) then
				print(fmt("Error at PC:%08x: %s", state.program_counter, ret))
				_procDebug.dumpProgram(safe_counter, 1)
				error(ret)
				break
			else
				yielded = ret
			end
		else
			yielded = ExecuteInstruction(bytecode, state.program_counter, executeFunction ~= nil)
		end
		if (yielded) then
			state.ticks = state.ticks + 1
			break
		end
	end
end
local state = false;
_ENV.print = print
_ENV.getBool = function()
		state = not state;
		return state;
	end
onTick()