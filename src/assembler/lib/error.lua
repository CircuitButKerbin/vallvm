require("lib.utilitys")
---@class Exception : table
---@field __super "Exception"
---@field message string
---@field type string
---@field __parent table
---@field __child table
---@field caused fun(self: Exception, e: Exception)
---@field Throw fun(e: Exception)

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