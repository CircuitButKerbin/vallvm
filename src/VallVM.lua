function forEach(t, f)
	local r = {}
	for i, v in ipairs(t) do
		r[i] = f(i,v)
	end
	return r	
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
		return n, function (v) _State.g[k] = v; --[[printf("[DEBUG] \t |-WRITE %s <- %s", k , v)]] end
	end
	if (SI == 5) then
		local k, n = unpack("s2", bin, ptr+1)
		return n, function (v) _State.g[k] = v; --[[printf("[DEBUG] \t |-WRITE %s <- %s", k , v)]]  end
	end
end







_State = {
	ra_stack = {},
	stack = {},
	program = "",
	ip = 0,
	g = {},
	r = {},
	tick = function (stk)
		local op = stk.program:byte(stk.ip)
		-- print(string.format("[DEBUG] IP: %04X | OP: %02X [%s]", (stk.ip-1) & 0xFFFF, op or 0xDEAD, map[op] or "???"))
		--forEach(stk.stack, function(i, v) print(string.format("[DEBUG] \t | /\\ STACK[%d]: %s", i, type(v) == "string" and trinary(#v > 50, string.format("<%d Bytes>", #v), v) or v)) end)
		--print("[DEBUG] \t |/")
		local stack, program, nextip, data, write, yield = stk.stack, stk.program, 0, nil, nil, false
		if op == 1 then
			nextip, data = parseDataType(program, stk.ip+1, true)
			push(data)
		elseif op == 2 then
			nextip, write = writeDataType(program, stk.ip+1)
			write(pop())
		-- elseif op == 0x0B then
		-- 	push(~pop())
		elseif inRange(op, 3, 0x15) then
			local a, b = pop(), pop()
			nextip = stk.ip + 1
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
			nextip, data = parseDataType(program, stk.ip+1)
			--print(string.format("[DEBUG] \t |-LOAD %s -> %s", data, _State.g[data]))
			push(_State.g[data])
		elseif op==0x17 then
			nextip, write = writeDataType(program, stk.ip+1)
			write(peek())
		elseif op==0x18 then
			nextip, data = parseDataType(program, stk.ip+1, true)
			nextip, write = writeDataType(program, nextip)
			write(data)
		elseif op==0x19 then
			swap()
			nextip = stk.ip + 1
		elseif op==0x1A then
			dupe()
			nextip = stk.ip + 1
		elseif op==0x1B then
			pop()
			nextip = stk.ip + 1
		elseif op==0x1C then
			over()
			nextip = stk.ip + 1
		elseif op==0x20 then
			nextip, data = parseDataType(program, stk.ip+1)
			stk.ra_stack[#stk.ra_stack+1] = nextip
			_, stk.ip = program:find("\x2A\x08" .. data .. "\0")
		elseif op == 0x21 then
			if #stk.ra_stack == 0 then
				return true
			else
				stk.ip = table.remove(stk.ra_stack)
			end
		elseif inRange(op, 0x22, 0x27) then
			nextip, data = parseDataType(program, stk.ip+1)
			local stackState = pop()
			if (type(stackState)) == "number" then
				stackState = toBool(stackState)
			end
			local cond = (op == 0x22 or op == 0x25) or ((op == 0x23 or op == 0x26) and stackState) or ((op == 0x24 or op == 0x27) and not stackState)
			if cond then
				nextip = trinary(op>=0x25, stk.ip + data, data)
			end
		elseif op==0x28 then
			nextip, data = parseDataType(program, stk.ip+1)
			local args, returns;
			nextip, args = parseDataType(program, nextip)
			nextip, returns = parseDataType(program, nextip)
			--printf("[DEBUG] \t |-FN: %s", data)
			args = pull(args)
			--forEach(args, function(i, v) print(string.format("[DEBUG] \t |   ARG[%d]: %s", i, v)) end)
			data = table.pack(resolveObject(data)(table.unpack(args)))
			for i=1, returns do
				push(data[i])
			end
		elseif op==0x29 then
			yield = true
			nextip = stk.ip + 1
		elseif op==0x2A or op==0x31 or op==0x30 then
			nextip = stk.ip + 1
		end
		stk.ip = nextip
		return yield
	end
}

local stk = {}
pop, push, cut, pull, peek, swap, dupe, over = function()
	local v = stk[#stk]
	stk[#stk] = nil
	return v
end,
function(v)
	stk[#stk+1] = v
end,
function(n)
	for i=1, n do
		stk[#stk] = nil
	end
end,
function(n)
	local t = {}
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

function Main()
	local file, err = io.open("./assembler/out/firmware.val")
	assert(file, string.format("Could not open file: %s", err))
	_State.program = file:read("all")
	file:close()
	print(string.format("loaded %d bytes", #_State.program))
	local t = os.clock()
	_, _State.ip = _State.program:find("\x2A\x08init\0")
	_State.ip = _State.ip + 1
	local c = 0
	while (not _State:tick()) do end
	_, _State.ip = _State.program:find("\x2A\x08onTick\0")
	_State.ip = _State.ip + 1
	while (not _State:tick()) do end
	_, _State.ip = _State.program:find("\x2A\x08onDraw\0")
	_State.ip = _State.ip + 1
	while (not _State:tick()) do end
	print("VM Finished in " .. (os.clock() - t)*1000 .. "ms")
end

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


Main()

