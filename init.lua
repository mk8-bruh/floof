local _PATH = (...):match("(.-)[^%.]+$")
local core = require((_PATH .. ".core"):match("%.(.+)"))

-- Import core modules
local object = core.object
local class = core.class
local input = core.input
local hitbox = core.hitbox
local array = core.array

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
        
        -- Hook into LOVE2D callbacks
        local old = {}
        for _, f in ipairs(loveCallbackNames) do
            old[f] = love[f] or function() end
        end
        
        -- Handle blocking callbacks (input is handled by input module)
        for _, f in ipairs{"filedropped", "directorydropped", "joystickadded", "joystickremoved", "joystickaxis", "joystickhat", "joystickpressed", "joystickreleased", "gamepadaxis", "gamepadpressed", "gamepadreleased"} do
            love[f] = function(...)
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