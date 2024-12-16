file = io.open("./assembler/out/firmware.val")
assert(file, string.format("Could not open file: %s", err))
_State = {}

_State.program = file:read("all")
file:close()

screen = {
	drawText = function(x, y, text)
		print(string.format("[DEBUG] drawText(%d, %d, %s)", x, y, text))
	end
}

print (string.format("loaded %d bytes", #_State.program))
local t = os.clock()
formatted = ""
for i = 1, #_State.program do
	formatted = formatted .. string.format("%02X", _State.program:byte(i))
end
--screen.drawText(0, 0, formatted)
print("Native Finished in " .. (os.clock() - t)*1000 .. "ms")