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