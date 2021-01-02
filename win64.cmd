@echo off

set MINGWDIR=C:\MinGW\bin
set PATH=%PATH%;%MINGWDIR%

call vsprompt.cmd -arch=x64 -host_arch=x64

if [%1]==[] (set target=all) else (set target=%1)
goto %target%

:clean
rd /s /q build
rd /s /q bin
rd /s /q dist
pushd lib\luajit\src
del buildvm.exp buildvm.lib lua51.dll lua51.exp lua51.lib luajit.exe luajit.exp luajit.lib minilua.exp minilua.lib vmdef.lua
popd
pushd lib\luajit-imgui\lua\imgui
del cdefs.lua glfw.lua sdl.lua
popd

:all
if not exist build md build
if not exist bin md bin

rem cimgui_sdl
cl /MP /O2 /LD /MD /DIMGUI_IMPL_API="extern \"C\" __declspec(dllexport)" /DIMGUI_DISABLE_OBSOLETE_FUNCTIONS /Fo.\build\ /I.\lib\sdl2\include /I.\lib\luajit-imgui\cimgui\imgui /I.\lib\luajit-imgui\cimgui\imgui\libs\gl3w /nologo .\lib\luajit-imgui\cimgui\cimgui.cpp .\lib\luajit-imgui\cimgui\imgui\backends\*.cpp .\lib\luajit-imgui\cimgui\imgui\*.cpp .\lib\luajit-imgui\cimgui\imgui\libs\gl3w\GL\gl3w.c .\lib\luajit-imgui\extras\cimgui_extras.cpp /link .\lib\sdl2\lib\x64\SDL2.lib .\lib\sdl2\lib\x64\SDL2main.lib opengl32.lib /out:.\bin\cimgui_sdl.dll /implib:.\build\cimgui_sdl.lib

rem luajit
pushd lib\luajit\src
call msvcbuild
set PATH=%PATH%;%cd%
popd

rem lua bindings
pushd lib\luajit-imgui\lua
luajit generator.lua
popd

rem dist
xcopy .\lib\luajit-imgui\lua\imgui .\dist\lua\imgui\ /Y
xcopy .\bin\cimgui_sdl.dll .\dist\cimgui_sdl.dll* /Y
