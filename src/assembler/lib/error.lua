
---@class Exception : table
---@field __super "Exception"
---@field message string
---@field type string
---@field __parent table
---@field __child table
---@field caused fun(self: Exception, e: Exception)
---@field Throw fun(e: Exception)

--#region Pretty Print Table
--#TODO move this to a seperate file
function printf(...)
    print(string.format(...))
end
local function formatprimative(v, bin)
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
local function prettyPrintTable (T, indent, displayed)
	indent = indent or 0
	local displayed = displayed or {}
	_ = (indent==0) and print(string.rep("    ", indent) .. "{")
	for k, v in pairs(T) do
		if (T == v) then
			print(string.rep("    ", indent) .. string.format("\t[%s] = \x1B[31m<recursion>\x1B[0m", formatprimative(k)))
		elseif (type(v) == "table") then
			if (displayed[v]) then
				print(string.rep("    ", indent) .. string.format("\t[%s] = \x1B[31m<recursion>\x1B[0m", formatprimative(k)))
			else
				displayed[v] = true
				prettyPrintTable(v, indent + 2, displayed)
			end
		else
			print(string.rep("    ", indent) .. string.format("\t[%s] = %s", formatprimative(k), formatprimative(v)))
		end
	end
	print(string.rep("    ", indent) .. "}")
end
--#endregion




local _ExceptionCounter = 0
local _ExceptionList = {}

local function getException(ExceptionString)
    assert(type(ExceptionString) == "string", "ExceptionString must be a string (was " .. type(ExceptionString) .. ")")
    return _ExceptionList[tonumber(string.sub(ExceptionString, 20, 26), 16)]
end

local function getExceptionString(Exception)
    return string.format("ExceptionInstance<%08X>", Exception.ExceptionID)
end

local function caused (self, e)
    assert(e, "caused must be called with an exception")
    print(self.type, "caused", e)
    local root = {}
    if self.__child then
        self.__child:caused(e)
    else
        e.__parent = self
        self.__child = e
    end
    if (self.__parent) then
        root = self.__parent
    else
        root = self
    end
    error(root)
end

function Assert(condition, e)
    if not condition then
        Throw(e)
    end
end


local function new (type, message)
    _ExceptionCounter = _ExceptionCounter + 1
    return setmetatable({
        __super = "Exception",
        type = type,
        message = message,
        __parent = nil,
        __child = nil,
        caused = caused,
        ExceptionID = _ExceptionCounter
    },{
        __tostring = function(self)
            return getExceptionString(self)
        end
    })
end
function Throw(e)
    if (type(e) ~= "table") then
        error(new("RawException", e))
    end
    print("Exception Thrown")
    prettyPrintTable(e)
    e.__super = "Exception"
    e.caused = caused
    error(e)
end

---wrapped pcall for more conveient handling of exceptions
---
---@param try table unpacked into pcall
---@param catch fun(e: Exception): any
---@param finally fun()
---@return any
---@overload fun(try: table, catch: fun(e: Exception)): any
function Try(try, catch, finally)
    finally = finally or function() end
    local status, exception = pcall(table.unpack(try))
    if not status then
        local status, handled = pcall(catch, exception)
        if status then
            return handled
        end
        exception:caused(new("UnhandledException<".. exception.type .. ">", exception.message))
    end
    finally()
    return exception
end

return {
    new = new,
    Throw = Throw,
    Try = Try,
    getException = getException,
}