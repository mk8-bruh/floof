local _PATH = (...):match("(.-)[^%.]+$")
local core = require((_PATH .. ".core"):match("%.(.+)"))

-- Import core modules
local object = core.object
local class = core.class
local input = core.input
local hitbox = core.hitbox
local array = core.array

-- Import inputSystem
local inputSystem = require(_PATH .. ".input")

-- Root object management
local rootObject = nil

-- LOVE2D callback names that need special handling
local loveCallbackNames = {
    "resize", "update", "draw", "quit",
    "filedropped", "directorydropped",
    "joystickadded", "joystickremoved",
    "joystickaxis", "joystickhat", "joystickpressed", "joystickreleased",
    "gamepadaxis", "gamepadpressed", "gamepadreleased"
}

-- Main library interface
local floof = {
    -- Core functionality
    is = object.is,
    isObject = object.is,
    new = object.new,
    newObject = object.new,
    
    -- Class system
    class = class,
    
    -- Array utilities
    array = array,
    
    -- Hitbox detection
    checks = hitbox.checks,
    
    -- InputSystem
    inputSystem = inputSystem,
    
    -- Root object management
    setRoot = function(obj)
        if obj ~= nil and not object.is(obj) then
            error(("Invalid object (got: %s (%s))"):format(tostring(obj), type(obj)), 2)
        end
        rootObject = obj
        input.setRoot(obj)
    end,
    
    getRoot = function()
        return rootObject
    end,
    
    -- Initialize FLOOF with LOVE2D
    init = function()
        if not love then return end
        
        -- Initialize input system
        input.init()
        
        -- Initialize inputSystem
        inputSystem.init()
        
        -- Hook into LOVE2D callbacks
        local old = {}
        for _, f in ipairs(loveCallbackNames) do
            old[f] = love[f] or function() end
        end
        
        -- Hook mouse input
        love.mousepressed = function(x, y, button, isTouch)
            -- Route to inputSystem
            inputSystem.handleEvent("mousepressed", x, y, button, isTouch)
            
            local root = input.getRoot()
            if button and not isTouch and root then
                root:keypressed(("mouse%d"):format(button))
            end
            if button and not isTouch and root and root:check(x, y) and root:pressed(x, y, button) ~= false then
                return
            end
            old.mousepressed(x, y, button, isTouch)
        end
        
        love.mousemoved = function(x, y, dx, dy, isTouch)
            -- Route to inputSystem
            inputSystem.handleEvent("mousemoved", x, y, dx, dy, isTouch)
            
            local root = input.getRoot()
            if love.mouse.getRelativeMode() and root then
                root:mousedelta(dx, dy)
                return
            end
            if not isTouch and root then
                local r = false
                for i, b in ipairs(root.presses) do
                    if type(b) == "number" then
                        if root:moved(x, y, dx, dy, b) then
                            r = true
                        end
                    end
                end
                if r then
                    return
                end
            end
            old.mousemoved(x, y, dx, dy, isTouch)
        end
        
        love.mousereleased = function(x, y, button, isTouch)
            -- Route to inputSystem
            inputSystem.handleEvent("mousereleased", x, y, button, isTouch)
            
            local root = input.getRoot()
            if button and not isTouch and root then
                root:keyreleased(("mouse%d"):format(button))
            end
            if button and not isTouch and root and root.presses:find(button) then
                root:released(x, y, button)
                return
            end
            old.mousereleased(x, y, button, isTouch)
        end
        
        love.wheelmoved = function(x, y)
            local root = input.getRoot()
            return root and root.isHovered and root:scrolled(y) or old.wheelmoved(x, y)
        end
        
        -- Hook touch input
        love.touchpressed = function(id, x, y)
            local root = input.getRoot()
            if root and root:check(x, y) and root:pressed(x, y, id) ~= false then
                return
            end
            old.touchpressed(id, x, y)
        end
        
        love.touchmoved = function(id, x, y, dx, dy)
            local root = input.getRoot()
            if root and root.presses:find(id) and root:moved(x, y, dx, dy, id) then
                return
            end
            old.touchmoved(id, x, y, dx, dy)
        end
        
        love.touchreleased = function(id, x, y)
            local root = input.getRoot()
            if root and root.presses:find(id) then
                root:released(x, y, id)
                return
            end
            old.touchreleased(id, x, y)
        end
        
        -- Hook keyboard input
        love.keypressed = function(key, scancode, isrepeat)
            -- Route to inputSystem
            inputSystem.handleEvent("keypressed", key, scancode, isrepeat)
            
            local root = input.getRoot()
            if root and root:keypressed(key, scancode, isrepeat) then
                return
            end
            old.keypressed(key, scancode, isrepeat)
        end
        
        love.keyreleased = function(key, scancode)
            -- Route to inputSystem
            inputSystem.handleEvent("keyreleased", key, scancode)
            
            local root = input.getRoot()
            if root and root:keyreleased(key, scancode) then
                return
            end
            old.keyreleased(key, scancode)
        end
        
        love.textinput = function(text)
            local root = input.getRoot()
            if root and root:textinput(text) then
                return
            end
            old.textinput(text)
        end
        
        -- Handle other blocking callbacks
        for _, f in ipairs{"filedropped", "directorydropped", "joystickadded", "joystickremoved", "joystickaxis", "joystickhat", "joystickpressed", "joystickreleased", "gamepadaxis", "gamepadpressed", "gamepadreleased"} do
            love[f] = function(...)
                -- Route joystick events to inputSystem
                if f == "joystickadded" then
                    inputSystem.handleJoystickAdded(...)
                elseif f == "joystickremoved" then
                    inputSystem.handleJoystickRemoved(...)
                else
                    -- Route other joystick events
                    inputSystem.handleEvent(f, ...)
                end
                
                return rootObject and rootObject[f](rootObject, ...) or old[f](...)
            end
        end
        
        -- Handle non-blocking callbacks
        for _, f in ipairs{"resize", "update", "draw", "quit"} do
            love[f] = function(...)
                old[f](...)
                
                if rootObject then
                    rootObject[f](rootObject, ...)
                end
            end
        end
        
        -- Create default root object if none exists
        if not rootObject then
            rootObject = object.new({check = true})
            input.setRoot(rootObject)
        end
    end
}

-- Module metatable for convenient access
return setmetatable(floof, {
    __index = function(t, k)
        if k == "root" then
            return rootObject
        end
        return t[k]
    end,
    __newindex = function(t, k, v)
        if k == "root" then
            if v ~= nil and not object.is(v) then
                error(("Invalid object (got: %s (%s))"):format(tostring(v), type(v)), 2)
            end
            floof.setRoot(v)
        else
            rawset(t, k, v)
        end
    end,
    __metatable = {},
    __tostring = function() return 'FLOOF' end,
    __call = function(_, ...)
        local s, v = pcall(object.new, ...)
        if not s then
            error(v, 2)
        else
            return v
        end
    end
})