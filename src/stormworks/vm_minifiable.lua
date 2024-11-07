---@diagnostic disable
local ps = {
	ticks = 0;
	init = false,
	stk = {},
	reg = {},
	pc = 1,
	pg = "",
	globals = {},
	fns = {},
	RAS = {},
	cycles = 0,
}

local function RGE(eN)
	local function split(str, sep)
		local sep, fields = sep or ":", {}
		str:gsub(_S.format("([^%s]+)", sep), function(c) fields[#fields+1] = c end)
		return fields
	end
	if (eN:match("%.")) then
		local path = split(eN, "%.")
		local obj = _ENV
		for i=1, #path do
			obj = obj[path[i]]
			if (not obj) then
				return nil
			end
		end
		return obj
	end
	return _ENV[eN]
end
iB = input.getBool
iN = input.getNumber
oN = output.setNumber
oB = output.setBool
live = true
ER = ""
_E = function (er)
	live = false
	ER = er
end
_V = 0
_S = string
_T = table
_D = screen.drawText
local rdy;
local mls = 0x3F
local rA = 0
local t=0
local L =0
local function tB(x)
	return x == 1 and true;
end
function tI(b)
	if (b) then return 1 end
	return 0
end
function fmt(...)
	return _S.format(...)
end

function onTick()
	if rdy and live then if L>0 then EB(ps.pg, ps, "onTick") else EB(ps.pg, ps, "init"); L=1 end elseif not rdy and live then
		if (t == 0) then
			t=t+1
			return
		end
		for i=0, 31 do
			oB(i+1, tB((rA >> i) & 1))
		end
		local c = ""
		local v = 0;
		for i=0, 31 do
			v = v | (tI(iB(i+1)) << i)
		end
		_V = v
		for i=0, 3 do
			c = c .. _S.char(v >> (i*8) & 0xFF)
		end
		ps.pg = ps.pg .. c
		if (mls == rA) then rdy = true end
		rA = rA + 1
		t=t+1
	end
end
--5x5
function onDraw()
	if rdy and live then EB(ps.pg, ps, "onDraw") elseif live and not rdy then
		_D(8, 8, fmt("Loading %%%.2f | %08X", rA/mls * 100, _V))
	else
		_D(0, 32*5 - 6, fmt("DIED | %s", ER))
		for i=0, 15 do
			_D(0, i*6, fmt("%1X0 |", i))
			for j=0, 15 do
				_D(i*12 + 20, j*6, fmt("%02X", ps.pg:byte(i + j*8) or 0))
			end
		end
	end
end



function EB(bytecode, s, executeFunction)
	function cut(t, count)
		for i=1, count do
			_T.remove(t, #t)
		end
	end
	function pull(count, ...)
		return _T.unpack(_T.pack(...), 1, count);
	end
	function S(...)
		for i, v in ipairs({...}) do
			s.stk[#s.stk+1] = v
		end
	end
	function RF(bytecode)
		local fns = {}
		local i = 0
		while _S.find(bytecode, _S.char(0x2A), i) do
			local dL = _S.find(bytecode, _S.char(0x2A), i) + 1
			i = dL
			local _, t, len, name = PO(bytecode, i)
			i = i + len
			fns[name] = {
				pointer = i,
			}
		end
		s.fns = fns;
	end
	function PO(bytecode, location)
		local typeDef = _S.byte(bytecode, location)
		local Type = typeDef & 0x1F
		if (Type == 0) then
			return nil, 0, 1
		end
		if (typeDef & 0x40 == 1) then
			return s.reg[typeDef & 0x1F], 9, 1
		end
		if (Type <= 3) then
			return _S.unpack(Type==3 and "f" or fmt("i%d", Type*2), bytecode, location+1), Type, Type==1 and 3 or 5
		end
		if (Type == 5) then
			local len = _S.unpack("i2", bytecode, location+1)
			return _S.sub(bytecode, location+3, location+2+len), 5, len+3
		end
		if (Type == 8) then
			local str = _S.unpack("z", bytecode, location+1)
			return s.globals[str], 8, #str + 2, str
		end
	end
	function WO(v, t, _, n)
		if (t == 8) then
			s.globals[n] = v
			return
		end
		if (t == 9) then
			s.reg[n] = v
			return
		end
		
	end
	function EI(bytecode, location, exitOnReturn)
		ps.cycles = ps.cycles + 1
		local op = _S.byte(bytecode, location)
		if (op==1) then 
			local v, t, len = PO(bytecode, location+1)
			S(v)
			s.pc = location + 1 + len
		elseif (op==2) then 
			local v, t, len, n = PO(bytecode, location+1)
			WO(_T.remove(s.stk), t, len, n)
			s.pc = location + 1 + len
		elseif (op==11) then 
			s.stk[#s.stk] = ~s.stk[#s.stk]
			s.pc = location + 1
		elseif (3<=op and op<=0x15) then 
			local a, b = s.stk[#s.stk], s.stk[#s.stk-1]
			cut(s.stk, 2)
			if (op==3) then
				S(a + b)
			elseif (op==4) then
				S(a - b)
			elseif (op==5) then
				S(a * b)
			elseif (op==6) then
				S(a / b)
			elseif (op==7) then
				S(a % b)
			elseif (op==8) then
				S(a & b)
			elseif (op==9) then
				S(a | b)
			elseif (op==10) then 
				S(a ~ b)
			elseif (op==12) then 
				S(a << b)
			elseif (op==13) then 
				S(a >> b)
			elseif (op==16) then 
				S(a == b)
			elseif (op==17) then 
				S(a ~= b)
			elseif (op==18) then 
				S(a < b)
			elseif (op==19) then 
				S(a > b)
			elseif (op==20) then 
				S(a <= b)
			elseif (op==21) then 
				S(a >= b)
			end
			s.pc = location + 1
		elseif (op==22) then 
			local v, t, len, n = PO(bytecode, location+1)
			S(v)
			s.pc = location + len + 1
		elseif (op==23) then 
			local v, t, len, n = PO(bytecode, location+1)
			WO(_T.remove(s.stk, #s.stk), t, _, n)
			s.pc = location + len + 1
		elseif (op==24) then 
			local v1, t1, len, n1 = PO(bytecode, location+1)
			local v2, t2, len2, n2 = PO(bytecode, location+1 + len)
			WO(v2, t1, len2, n1)
			s.pc = location + 1 + len + len2
		elseif (op==32) then 
			local _, t, len, n = PO(bytecode, location+1)
			s.RAS[#s.RAS+1] = s.pc
			s.pc = s.fns[n].pointer
		elseif (op==33) then 
			if (exitOnReturn) then
				return true
			end
			s.pc = s.RAS[#s.RAS]
			cut(s.RAS, 1)
		elseif (op >= 34 and op <= 39) then 
			local v, t, len = PO(bytecode, location+1)
			local stkState = _T.remove(s.stk, #s.stk)
			if (type(stkState) ~= "boolean") then
				stkState = stkState ~= 0
			end
			local cond = (op == 34 or op == 37) or ((op == 35 or op == 38) and stkState) or ((op == 36 or op == 39) and not stkState)
			cut(s.stk, 1)
			if (cond) then
				s.pc = (op>=37 and (s.pc + v) or v)
			else
				s.pc = s.pc + len + 1
			end
		elseif (op == 25) then
			local a, b = s.stk[#s.stk], s.stk[#s.stk-1]
			s.stk[#s.stk] = b
			s.stk[#s.stk-1] = a
			s.program_counter = location + 1
		elseif (op == 26) then
			s.stk[#s.stk+1] = s.stk[#s.stk]
			s.program_counter = location + 1
		elseif (op == 27) then
			cut(s.stk, 1)
			s.program_counter = location + 1
		elseif (op ==28) then
			s.stk[#s.stk+1] = s.stk[#s.stk-1];
		elseif (op==40) then 
			local _, t, len, externName = PO(bytecode, location+1)
			local fn = RGE(externName)
			local argCount, t, len2 = PO(bytecode, location + 1 + len)
			local args = {}
			for i=1, argCount do
				args[i] = s.stk[#s.stk - argCount + i]
			end
			cut(s.stk, argCount)
			local ret = _T.pack(fn(_T.unpack(args)))
			local returns, t, len3 = PO(bytecode, location+1 + len + len2)
			for i=1, returns do
				S(ret[i])
			end
			s.pc = location + 1 + len + len2 + len3
		elseif (op==41) then 
			return true
		elseif (op == 49) then
			s.pc = location + 1
		else
			_E(fmt("unkop: %02X", op or 0))
			return true
		end
	end
	if (not s.init) then
		RF(bytecode)
		s.init = true
	end
	if (executeFunction) then
		if (s.fns[executeFunction]) then
			s.pc = s.fns[executeFunction].pointer
		else
			
		end
	end
	while true do
		local opcode = _S.byte(bytecode, s.pc)
		local yielded;
		yielded = EI(bytecode, s.pc, true)
		if (yielded) then
			s.ticks = s.ticks + 1
			break
		end
	end
end