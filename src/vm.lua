local processor_state = {
	stack = {},
	register = {},
	program_counter = 1,
	program = "\x16\x05\x0D\x00Hello, world!\x28\x08print\0\x01\x01\x00\x01\x00\x00\x29",
	globals = {},
	functions = {},
	return_address_stack = {}
}

---@enum OperandType


---@diagnostic disable-next-line
function onTick()
	--#TODO load program code
	ExecuteBytecode(processor_state.program, processor_state)
end

---@diagnostic disable-next-line
function onDraw()

end

function fmt(...)
	return string.format(...)
end

function ExecuteBytecode(bytecode, state)
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
			i = i + len
			local argCount = ParseOperand(bytecode, i)
			assert(t == 1 or t == 2, fmt("Function argument count must be of integer type %d", t))
			i = i + len
			functions[#functions+1] = {
				name = name,
				pointer = i,
				argsCount = argCount
			}
		end
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
		end
		if (t == 9) then
			state.register[n] = v
		end
		error(fmt("Attempted to write to operand %d [PC:%08x]", t, state.program_counter or 0xDEADBEEF))
	end
	function ExecuteInstruction(bytecode, location)
		local op = string.byte(bytecode, location)
		if (op==1) then -- push
			local v, t, len = ParseOperand(bytecode, location+1)
			put(v)
			state.program_counter = location + 1 + len
		elseif (op==2) then -- pop
			local v, t, len, n = ParseOperand(bytecode, location+1)
			WriteOperand(table.remove(state.stack), t, len, n)
			state.program_counter = location + 1 + len
		elseif (op==11) then
			state.stack[#state.stack] = ~state.stack[#state.stack]
			state.program_counter = location + 1
		elseif (3<=op and op<=0x15) then
			local a, b = state.stack[#state.stack], state.stack[#state.stack-1]
			cut(state.stack, 2)
			if (op==3) then
				put(a + b)
			elseif (op==4) then
				put(a - b)
			elseif (op==5) then
				put(a * b)
			elseif (op==6) then
				put(a / b)
			elseif (op==7) then
				put(a % b)
			elseif (op==8) then
				put(a & b)
			elseif (op==9) then
				put(a | b)
			elseif (op==0xA) then -- 0x0A
				put(a ~ b)
			elseif (op==0xC) then -- 0x0C
				put(a << b)
			elseif (op==0xD) then -- 0x0D
				put(a >> b)
			elseif (op==0x10) then -- 0x0E
				put(a == b)
			elseif (op==0x11) then -- 0x0F
				put(a ~= b)
			elseif (op==0x12) then -- 0x10
				put(a < b)
			elseif (op==0x13) then -- 0x11
				put(a > b)
			elseif (op==0x14) then -- 0x12
				put(a <= b)
			elseif (op==0x15) then -- 0x13
				put(a >= b)
			end
			state.program_counter = location + 1
		elseif (op==0x16) then 
			local v, t, len, n = ParseOperand(bytecode, location+1)
			put(v)
			state.program_counter = location + len + 1
		elseif (op==0x17) then
			local v, t, _, n = ParseOperand(bytecode, location+1)
			assert(t == 8 or t==9, fmt("Store requires a global variable name or register, got type %d", t))
			WriteOperand(table.remove(state.stack), t, _, n)
			state.program_counter = location + 1
		elseif (op==0x18) then
			local v1, t1, len, n1 = ParseOperand(bytecode, location+1)
			local v2, t2, len2, n2 = ParseOperand(bytecode, location+1 + len)
			assert(t1 == 8 or t1==9 and t2 == 8 or t2 == 9, fmt("Move requires a global variable name or register, got type %d", t1))
			WriteOperand(v2, t1, len2, n1)
			state.program_counter = location + 1 + len + len2
		elseif (op==0x20) then
			local _, t, len, n = ParseOperand(bytecode, location+1)
			assert(t == 8, fmt("Call requires a variable name, got type %d", t))
			assert(state.functions[n], fmt("Function %s not found", n))
			state.return_address_stack[#state.return_address_stack+1] = state.program_counter
			state.program_counter = state.functions[n].pointer
		elseif (op==0x21) then
			state.program_counter = state.return_address_stack[#state.return_address_stack]
			cut(state.return_address_stack, 1)
		elseif (op>=0x22 and op<=0x27) then
			local v, t, len = ParseOperand(bytecode, location+1)
			assert(t == 1 or t == 2, fmt("Jumps requires a i32 or i16, got type %d", t))
			local cond = (op==0x22 or op==0x25) or (op==0x23 or op==0x26) and state.stack[#state.stack] or (op==0x24 or op==0x27) and not state.stack[#state.stack]
			if (cond) then
				state.program_counter = (op>=0x25 and (state.program_counter + v) or v)
			else
				state.program_counter = state.program_counter + len
			end
		elseif (op==0x28) then
			local _, t, len, externName = ParseOperand(bytecode, location+1)
			assert(t == 8, fmt("invoke requires a variable name, got type %d", t))
			assert(_ENV[externName], fmt("Extern function %s not found", externName))
			local argCount, t, len2 = ParseOperand(bytecode, location + 1 + len)
			assert(t == 1 or t == 2, fmt("Extern function argument count must be of integer type %d", t))
			local args = {}
			for i=1, argCount do
				args[i] = state.stack[#state.stack - argCount + i]
			end
			local ret = table.pack(_ENV[externName](table.unpack(args)))
			local returns, t, len3 = ParseOperand(bytecode, location+1 + len + len2)
			assert(t == 1 or t == 2, fmt("Extern function return count must be of integer type %d", t))
			for i=1, returns do
				put(ret[i] or nil)
			end
			-- trim stack
			if (argCount > returns) then
				cut(state.stack, argCount - returns)
			end
			state.program_counter = location + 1 + len + len2 + len3
		elseif (op==0x29) then
			return true
		end
	end
	while true do
		local opcode = string.byte(bytecode, state.program_counter)
		if (ExecuteInstruction(bytecode, state.program_counter)) then
			break
		end
	end
end
_ENV.print = print
onTick()