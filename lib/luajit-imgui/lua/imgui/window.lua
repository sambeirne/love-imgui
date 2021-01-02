local function MainDockSpace(W)
    local ig = W.ig
    if not W.has_imgui_viewport then return end
    if (bit.band(ig.GetIO().ConfigFlags , ig.lib.ImGuiConfigFlags_DockingEnable)==0) then return end
    
    local dockspace_flags = bit.bor(ig.lib.ImGuiDockNodeFlags_NoDockingInCentralNode, ig.lib.ImGuiDockNodeFlags_AutoHideTabBar, ig.lib.ImGuiDockNodeFlags_PassthruCentralNode, ig.lib.ImGuiDockNodeFlags_NoTabBar, ig.lib.ImGuiDockNodeFlags_HiddenTabBar) --ImGuiDockNodeFlags_NoSplit
    ig.DockSpaceOverViewport(nil, dockspace_flags);
end
local M = {}

local function startGLFW(W, postf)
    local window = W.window
    local ig = W.ig
    while not window:shouldClose() do
    
        W.lj_glfw.pollEvents()
        
        window:makeContextCurrent()
        
        W.gllib.gl.glClear(W.gllib.glc.GL_COLOR_BUFFER_BIT)
        
        if W.preimgui then W.preimgui() end
        
        W.ig_impl:NewFrame()
        
        MainDockSpace(W)
        W:draw(ig)
        
        W.ig_impl:Render()

        --viewport branch
        if W.has_imgui_viewport then
            local igio = ig.GetIO()
            if bit.band(igio.ConfigFlags , ig.lib.ImGuiConfigFlags_ViewportsEnable) ~= 0 then
                local backup_current_context = W.lj_glfw.getCurrentContext();
                ig.UpdatePlatformWindows();
                ig.RenderPlatformWindowsDefault();
                window.makeContextCurrent(backup_current_context)
                --window:makeContextCurrent()
            end
        end
        
        window:swapBuffers()                    
    end
    if postf then postf() end
    W.ig_impl:destroy()
    window:destroy()
    W.lj_glfw.terminate()
end

function M:GLFW(w,h,title,args)
    args = args or {}
    local W = {args = args}
    local ffi = require "ffi"
    W.lj_glfw = require"glfw"
    W.gllib = require"gl"
    W.gllib.set_loader(W.lj_glfw)
    --local gl, glc, glu, glext = gllib.libraries()
    W.ig = require"imgui.glfw"

    W.lj_glfw.setErrorCallback(function(error,description)
        print("GLFW error:",error,ffi.string(description or ""));
    end)

    W.lj_glfw.init()
    local window = W.lj_glfw.Window(w,h,title or "")
    window:makeContextCurrent()
    if args.vsync then W.lj_glfw.swapInterval(1) end

    W.ig_impl = W.ig.Imgui_Impl_glfw_opengl3()
    
    local igio = W.ig.GetIO()
    igio.ConfigFlags = W.ig.lib.ImGuiConfigFlags_NavEnableKeyboard + igio.ConfigFlags
    local ok = pcall(function() return W.ig.lib.ImGuiConfigFlags_ViewportsEnable end)
    if ok then
        W.has_imgui_viewport = true
        igio.ConfigFlags = igio.ConfigFlags + W.ig.lib.ImGuiConfigFlags_DockingEnable
        if args.use_imgui_viewport then
            igio.ConfigFlags = igio.ConfigFlags + W.ig.lib.ImGuiConfigFlags_ViewportsEnable
        end
    end
    
    W.ig_impl:Init(window, true)
    
    W.window = window
    W.start = startGLFW
    return W
end

local function startSDL(W, postf)
    local ffi = require"ffi"

    local window = W.window
    local sdl = W.sdl
    local ig = W.ig
    local gl,glc = W.gllib.gl,W.gllib.glc
    local igio = ig.GetIO()
    local done = false;
    while (not done) do
        --SDL_Event 
        local event = ffi.new"SDL_Event"
        while (sdl.pollEvent(event) ~=0) do
            ig.lib.ImGui_ImplSDL2_ProcessEvent(event);
            if (event.type == sdl.QUIT) then
                done = true;
            end
            if (event.type == sdl.WINDOWEVENT and event.window.event == sdl.WINDOWEVENT_CLOSE and event.window.windowID == sdl.getWindowID(window)) then
                done = true;
            end
        end
        --standard rendering
        sdl.gL_MakeCurrent(window, W.gl_context);
        gl.glViewport(0, 0, igio.DisplaySize.x, igio.DisplaySize.y);
        gl.glClear(glc.GL_COLOR_BUFFER_BIT)
        
        if W.preimgui then W.preimgui() end

        W.ig_Impl:NewFrame()

        MainDockSpace(W)
        W:draw(ig)
        
        W.ig_Impl:Render()
        
        --viewport branch
        if W.has_imgui_viewport then
            local igio = ig.GetIO()
            if bit.band(igio.ConfigFlags , ig.lib.ImGuiConfigFlags_ViewportsEnable) ~= 0 then
                ig.UpdatePlatformWindows();
                ig.RenderPlatformWindowsDefault();
                sdl.gL_MakeCurrent(window, gl_context)
            end
        end
        
        sdl.gL_SwapWindow(window);
    end
    
    -- Cleanup
    if postf then postf() end
    W.ig_Impl:destroy()

    sdl.gL_DeleteContext(gl_context);
    sdl.destroyWindow(window);
    sdl.quit();
end
function M:SDL(w,h,title,args)
    args = args or {}
    local W = {args = args}
    local ffi = require "ffi"
    W.sdl = require"sdl2_ffi"
    local sdl = W.sdl
    W.gllib = require"gl"
    W.gllib.set_loader(W.sdl)
    --local gl, glc, glu, glext = gllib.libraries()
    W.ig = require"imgui.sdl"

    if (sdl.init(sdl.INIT_VIDEO+sdl.INIT_TIMER) ~= 0) then
        print(string.format("Error: %s\n", sdl.getError()));
        return -1;
    end

    sdl.gL_SetAttribute(sdl.GL_CONTEXT_FLAGS, sdl.GL_CONTEXT_FORWARD_COMPATIBLE_FLAG);
    sdl.gL_SetAttribute(sdl.GL_CONTEXT_PROFILE_MASK, sdl.GL_CONTEXT_PROFILE_CORE);
    sdl.gL_SetAttribute(sdl.GL_DOUBLEBUFFER, 1);
    sdl.gL_SetAttribute(sdl.GL_DEPTH_SIZE, 24);
    sdl.gL_SetAttribute(sdl.GL_STENCIL_SIZE, 8);
    sdl.gL_SetAttribute(sdl.GL_CONTEXT_MAJOR_VERSION, 3);
    sdl.gL_SetAttribute(sdl.GL_CONTEXT_MINOR_VERSION, 2);
    local current = ffi.new("SDL_DisplayMode[1]")
    sdl.getCurrentDisplayMode(0, current);
    local window = sdl.createWindow(title or "", sdl.WINDOWPOS_CENTERED, sdl.WINDOWPOS_CENTERED, w, h, sdl.WINDOW_OPENGL+sdl.WINDOW_RESIZABLE); 
    W.gl_context = sdl.gL_CreateContext(window);
    if self.vsync then sdl.gL_SetSwapInterval(1) end

    
    W.ig_Impl = W.ig.Imgui_Impl_SDL_opengl3()
    
    local igio = W.ig.GetIO()
    igio.ConfigFlags = W.ig.lib.ImGuiConfigFlags_NavEnableKeyboard + igio.ConfigFlags
    local ok = pcall(function() return W.ig.lib.ImGuiConfigFlags_ViewportsEnable end)
    if ok then
        W.has_imgui_viewport = true
        igio.ConfigFlags = igio.ConfigFlags + W.ig.lib.ImGuiConfigFlags_DockingEnable
        if args.use_imgui_viewport then
            igio.ConfigFlags = igio.ConfigFlags + W.ig.lib.ImGuiConfigFlags_ViewportsEnable
        end
    end
    
    W.ig_Impl:Init(window, W.gl_context)

    W.window = window
    W.start = startSDL
    return W
end

return M