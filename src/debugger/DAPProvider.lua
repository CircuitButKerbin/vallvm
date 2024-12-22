local lsock = require("src/debugger/lsock")
---Log
---@param msg string
---@param lvl integer -1:DEBUG, 0:INFO, 1:WARN, 2:ERROR, 3:FATAL
---@overload fun(msg: string)
local function log(msg, lvl)
	if lvl == nil then
		lvl = 0
	end
	local t = {
		[-1] = "\x1B[38;5;200m0DEBUG\x1B[0m",
		[0] = "\x1B[38;5;238mINFO\x1B[0m",
		[1] = "\x1B[38;5;226mWARN\x1B[0m",
		[2] = "\x1B[38;5;196mERROR\x1B[0m",
		[3] = "\x1B[38;5;160mFATAL\x1B[0m"
	}
	print(string.format("\t[%s] : %s", t[lvl], msg))
end


---@class DAP_ProtocolMessage
---@field seq integer
---@field type 'request' | 'response' | 'event'

---@class DAP_Request : DAP_ProtocolMessage
---@field type 'request'
---@field command string
---@field arguments table

---@class DAP_Response : DAP_ProtocolMessage
---@field type 'response'
---@field request_seq integer
---@field success boolean
---@field command string
---@field message 'cancelled' | 'notStopped' | string | nil
---@field body any

---@class DAP_Event : DAP_ProtocolMessage
---@field type 'event'
---@field event string
---@field body any

---@alias False false
---@alias True true

---@class DAP_ErrorResponse : DAP_Response
---@field success False
---@field body table --#TODO define this

---@class DAPSession
---@field _sendMessage fun(self: DAPSession, msg: DAP_ProtocolMessage)
---@field registerRequestCallback fun(self:DAPSession, command: string, callback: fun(request: DAP_Request): DAP_Response)
---@field emitEvent fun(self: DAPSession, event: DAP_Event)
---@field _sendMessage fun(msg: DAP_ProtocolMessage)
---@field _callbacks table<string, fun(request: DAP_Request): DAP_Response>
---@field _segment_counter integer
---@field update fun(self: DAPSession)
---@field close fun(self: DAPSession)

---comment
---@param stream connection
---@return DAPSession
local function CreateDAPSession(stream)
	---@type DAPSession
	log("Session Started")
	stream:set_timeout(1)
	return {
		_segment_counter = 0,
		_callbacks = {},
		_session_state = 0,
		_buffer = "",
		_sendMessage = function(self, msg)
			msg.seq = self._segment_counter;
			self._segment_counter = self._segment_counter + 1
			local serialized = lsock.util.serializeJSON(msg)
			stream:write(string.format("Content-Length: %d\r\n\r\n%s", #serialized, serialized))
			if msg.type == "response" and msg.command == "terminate" and msg.success == true then
				self:close()
			end
		end,
		registerRequestCallback = function(self, command, callback)
			log(string.format("Registered callback for \'%s\'", command))
			self._callbacks[command] = callback
		end,
		emitEvent = function (self, event)
			log(string.format("Emitted event \'%s\'", event.event))
			self:_sendMessage(event)
		end,
		---@param self DAPSession
		update = function(self)
			local data = stream:read()
			if not data then
				return true
			end
			while data:match("Content%-Length: (%d+)\r\n\r\n") do
				local _, headerE, contentL = data:find("Content%-Length: (%d+)\r\n\r\n")
				if not headerE then
					log("Failed to parse header, discarding...", 1)
					break
				end
				local _json = data:sub(headerE, headerE + contentL)
				if #_json < tonumber(contentL) then
					log("Incomplete message recieved ", 1)
					break
				end
				local parsed, body = pcall(lsock.util.deseriallizeJSON, _json)
				---@type DAP_ProtocolMessage
				body = body
				if not parsed then
					log("Failed to parse JSON, discarding...", 1)
					break
				end
				data = data:sub(headerE + contentL, #data)
				if body.type == "request" and body.seq then
					---@type DAP_Request
					body = body;
					if self._callbacks[body.command] then
						local success, response = pcall(self._callbacks[body.command], body)
						if not success then
							log(string.format("Callback for \'%s\' threw exception \"%s\"", body.command, response), 2)
						end
						response.request_seq = body.seq
						response.type = "response"
						self:_sendMessage(response)
						log(string.format("Sent response to \'%s\'", body.command))
					else
						log(string.format("No callback registered for command \'%s\'", body.command), 1)
					end
				else
					log("Invalid message format, discarding...", 1)
				end
			end
			return true
		end,
		close = function (self)
			stream:close()
			log("Session Closed")
			os.exit(0, true)
		end
	}
end
return { CreateDAPSession=CreateDAPSession, Socket=lsock.socket, Log=log }