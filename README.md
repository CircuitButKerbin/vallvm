# VallVM
## About
Vall ([as in the second Joolian moon](https://wiki.kerbalspaceprogram.com/wiki/Vall)) VM is a simplistic bytecode running ontop of Lua for use in Stormworks, nullifying the 4096 (as of now) character limit imposed on scripts by allowing the program to be split
and stored across multiple scripts, and loaded and excuted on one seamlessly.
## Usage
To start, first you need to write a program in VallASM. It's pretty bare-bones at the moment, but you need three functions defined for stormworks. `fnDef init`, `fnDef onTick`, `fnDef onDraw`.
The `init` function is called only once after the program finishes loading. You cannot invoke functions to draw onto the screen here. The others are identical in usage to their stormworks counterparts.
An Hello, world! program would look like this:
```asm
fnDef init:
  ret

fnDef onTick:
  ret

fnDef onDraw:
  push 1
  push 1
  push "Hello, world!"
  invoke "screen.drawText", 3, 0 ; screen.drawText(1,1,"Hello, world!")
  ret
```
In this program, `invoke` is the instructon to call an Lua funciton that is defined in the enviroment (`_ENV` table in stormworks). The invoke instruction is `invoke <fn> <nargs> <nreturns>`, with `<fn>` being the function to invoke, `<nargs>` being the number of input arguments, and `<nreturns>` being the number of arguments to expect back.
After writing your program, you would run `assembler.lua` in the assembler directory, and pass it the file to assemble, with an `-O` argument to print the output to stdout in a escaped format that can be pasted into Lua.

In stormworks, you would make two lua scripts with interconnected composite channels, and have on script run `loader.lua` and the other `vm_min.lua`. `loader.lua` needs the escaped program pasted into it's `program` variable, and `vm_min.lua` needs `mls` set to the size of the program. At the moment, the script only uses the boolean channels when loading the program, which means it can only load 4 bytes / tick, or 240 bytes/s. In the future it will be expanded to utilize floats for data transmission, most likely sending 23 bits per float channel, giving a new bandwidth of 5.520 Kb/s.

