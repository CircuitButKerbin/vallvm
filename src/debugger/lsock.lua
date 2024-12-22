
local lsock = {}

---@param t table<any>
---@param f fun(k:any, v:any):any
---@return table
local function forEach(t, f)
	local r, i = {}, 1
	for k, v in pairs(t) do
		r[i] = f(k, v)
		i = i + 1
	end
	return r
end


local _socket = assert(package.loadlib("tools\\lsock\\target\\release\\lsock.dll", "luaopen_lsock"))()
-- print("Lsock Initalized")
local lsock = {}
-- prettyPrintTable(_socket)
---@class ipaddr
---@field ip string
---@field port integer

---@class listener
---@field accept fun(self:listener): connection, ipaddr

---@class connection
---@field read fun(self:connection): string
---@field write fun(self:connection, data: string)
---@field close fun(self:connection)
---@field set_timeout fun(self:connection, timeout_milli: integer)

---@class socket
---@field bind fun(addr: string): listener
---@field open fun(addr: string): connection
lsock.socket = {
	bind = function(addr)
		local listener = _socket.bind(addr)
		return {
			_listener = listener;
			accept = function (self)
				local conn, ip = self._listener:accept()
				return {
					_socket = conn;
					read = function(self)
						return self._socket:read()
					end,
					write = function(self, data)
						self._socket:write(data)
					end,
					close = function(self)
						self._socket:close(self._socket)
					end,
					set_timeout = function(self, timeout_milli)
						self._socket:set_timeout(timeout_milli)
					end
				}, {
					ip = ip:ip();
					port = ip:port();
				}
			end
		}
	end,
	open = function(addr)
		local conn = _socket.open(addr);
		return {
			_socket = conn;
			read = function(self)
				return lsock.read(self._socket)
			end,
			write = function(self, data)
				lsock.write(self._socket, data)
			end,
			close = function(self)
				lsock.close(self._socket)
			end,
			set_timeout = function(self, timeout_milli)
				lsock.set_timeout(self._socket, timeout_milli)
			end
		}
	end
}

---Seralizes v to a json string
---@param _v any
---@return string
local function serializeJSON(_v)
	if type(_v) == "string" then
		if _v:match("\xFF") then
			return "[]"
		end	
		return string.format("%s", formatprimative(_v, false, true))
	end	
	if type(_v) == "number" then
		if _v % 1 == 0 then
			return string.format("%d", _v)
		else
			return string.format("%f", _v)
		end
	end
	if type(_v) == "table" then
		if #_v > 0 then
			return "[" .. table.concat(forEach(_v, function (k, v) return serializeJSON(v) end), ",") .. "]"
		else
			return "{" .. table.concat(forEach(_v, function (k, v) return string.format("\"%s\" : %s", k, serializeJSON(v)) end), ",") .. "}"
		end
	end
	if type(_v) == "boolean" then
		return tostring(_v)
	end
	if type(_v) == "nil" then
		return "null"
	end
	error(string.format("unable to seralize type \"%s\""))
end


---Deserializes a json string to a lua object
---@param _json any
---@return any
local function deserializeJSON(_json)
	return _socket.parse_json(_json)
end

lsock.util = {
	serializeJSON = serializeJSON,
	deseriallizeJSON = deserializeJSON
}

return lsock;