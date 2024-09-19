
---@class Exception : table
---@field __super "Exception"
---@field message string
---@field type string
---@field __parent table
---@field __child table
---@field Throw fun(e: Exception)

local function caused (self, e)
    e.__parent = self
    self.__child = e
    error(self)
end

function Assert(condition, e)
    if not condition then
        Throw(e)
    end
end


local function new (type, message)
    return {
        __super = "Exception",
        type = type,
        message = message,
        __parent = nil,
        __child = nil,
        caused = caused
    }
    
end
function Throw(e)
    if (type(e) ~= "table") then
        error({
            __super = "Exception",
            type = "Unknown",
            message = e
        })
    end
    e.__super = "Exception"
    e.caused = caused
    error(e)
end

---wrapped pcall for more conveient handling of exceptions
---
---@param try table unpacked into pcall
---@param catch fun(e: Exception): boolean
---@param finally fun()
---@return any
---@overload fun(try: table, catch: fun(e: Exception)): any
function Try(try, catch, finally)
    local status, exception = pcall(table.unpack(try))
    if not status then
        local status, handled = pcall(catch, exception)
        if status then
            return handled
        end
        exception.caused(new("UnhandledException", exception))
    end
    finally()
    return exception
end

return {
    new = new,
    Throw = Throw,
    Try = Try
}