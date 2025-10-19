

## Building in VSCode

Build normally: Ctrl + Shift + P
For debugging: Ctrl + Shift + P -> type "Run Task" -> choose "Build SnakeByte (Debug)" for debugging

Highlighter complained about external stuff for bin format:
    - Went to doinkythederp plugin > Settings > Changed NASM: Output Format to `elfx32`

## .vscode/tasks.json

Defines custom build commands we can run from VS Code.
Maps keyboard shortcuts like Ctrl + Shift + B to shell commands
**Can have multiple tasks (normal build, debug build, clean, etc.)

## .vscode/launch.json

Defines how to launch the program under a debugger (GDB).
Configures the debugger
Maps F5 to "build + run with debugger attached"
Lets us set breakpoints, inspect registers, step through code