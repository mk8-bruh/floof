local _PATH = (...):match("(.-)[^%.]+$")
local object = require(_PATH .. ".object")
local array = require(_PATH .. ".array")

-- Input callback names
local inputCallbackNames = {
    "pressed", "moved", "released", "cancelled",
    "scrolled", "hovered", "unhovered",
    "mousedelta", "keypressed", "keyreleased", "textinput"
}

-- Input state management
local inputState = {
    root = nil,
    lastHovered = nil
}

-- Helper functions
local function getPressPosition(id)
    if type(id) == "number" then
        return love.mouse.getPosition()
    else
        local s, x, y = pcall(love.touch.getPosition, id)
        if s then
            return x, y
        end
    end
end

-- Input object properties
local inputProperties = {
    isHovered = {
        get = function(self)
            if self == inputState.root then
                return self:check(love.mouse.getPosition())
            end
            return self.parent and self.parent.isHovered and self.parent.hoveredChild == self or false
        end
    },
    
    hoveredChild = {
        get = function(self)
            if not self.isHovered then return end
            local mouseX, mouseY = love.mouse.getPosition()
            for index, child in ipairs(self.children) do
                if child.isEnabled and child:check(mouseX, mouseY) then
                    return child
                end
            end
        end
    },
    
    pressedObject = {
        get = function(self)
            local internal = object.getInternal(self)
            if not internal.pressedObjectProxy then
                -- Create proxy on first access
                internal.pressedObjectProxy = setmetatable({}, {
                    __index = internal.pressedObject,
                    __newindex = function(t, k, v)
                        if not getPressPosition(k) then
                            error(("Invalid press ID: %s (%s)"):format(tostring(k), type(k)), 3)
                        end
                        if v ~= nil and not object.is(v) then
                            error(("Invalid object (got: %s (%s))"):format(tostring(v), type(v)), 3)
                        end
                        if v ~= nil and v.parent ~= self then
                            error(("Target must be a child of this object"), 2)
                        end
                        self:setPressTarget(k, v)
                    end
                })
            end
            return internal.pressedObjectProxy
        end
    },
    
    presses = {
        get = function(self)
            local internal = object.getInternal(self)
            local pressArray = array.new()
            for index, pressId in ipairs(internal.presses) do
                pressArray:append(pressId)
            end
            return pressArray
        end
    },
    
    press = {
        get = function(self)
            local internal = object.getInternal(self)
            return internal.presses[-1]
        end
    },
    
    isPressed = {
        get = function(self)
            local internal = object.getInternal(self)
            return #internal.presses > 0
        end
    }
}

-- Input object methods
local inputMethods = {
    setPressTarget = function(self, id, targetObject)
        if targetObject ~= nil and not object.is(targetObject) then
            error(("Invalid object (got: %s (%s))"):format(tostring(targetObject), type(targetObject)), 3)
        end
        if targetObject ~= nil and targetObject.parent ~= self then
            error(("Target must be a child of this object"), 3)
        end
        
        local internal = object.getInternal(self)
        local p = internal.pressedObject[id]
        if p == targetObject then return end
        
        if p then
            p:cancelled(id)
        end
        
        local x, y = getPressPosition(id)
        if targetObject and targetObject:pressed(x, y, id) ~= false then
            internal.pressedObject[id] = targetObject
        else
            internal.pressedObject[id] = nil
        end
    end,
    
    getPressPosition = function(self, i)
        if i == nil then
            i = -1
        end
        if not self.presses[i] then
            error(("Invalid index (got: %s (%s))"):format(tostring(i), type(i)), 3)
        end
        return getPressPosition(self.presses[i])
    end
}

-- Default input callbacks
local defaultInputCallbacks = {
    pressed = function(self, x, y, pressId)
        local internal = object.getInternal(self)
        internal.presses:append(pressId)
        
        for index, child in ipairs(self.children) do
            if child.isEnabled and child:check(x, y) and child:pressed(x, y, pressId) ~= false then
                internal.pressedObject[pressId] = child
                return true
            end
        end
    end,
    
    moved = function(self, x, y, deltaX, deltaY, pressId)
        local internal = object.getInternal(self)
        if internal.pressedObject[pressId] then
            if internal.pressedObject[pressId]:moved(x, y, deltaX, deltaY, pressId) ~= true and not internal.pressedObject[pressId]:check(x, y) then
                self:setPressTarget(pressId)
            end
            return true
        end
    end,
    
    released = function(self, x, y, pressId)
        local internal = object.getInternal(self)
        internal.presses:remove(pressId)
        if internal.pressedObject[pressId] then
            internal.pressedObject[pressId]:released(x, y, pressId)
            internal.pressedObject[pressId] = nil
            return true
        end
    end,
    
    cancelled = function(self, pressId)
        local internal = object.getInternal(self)
        internal.presses:remove(pressId)
        if internal.pressedObject[pressId] then
            internal.pressedObject[pressId]:cancelled(pressId)
            internal.pressedObject[pressId] = nil
        end
    end,
    
    scrolled = function(self, scrollAmount)
        if self.isHovered and self.hoveredChild then
            self.hoveredChild:scrolled(scrollAmount)
            return true
        end
    end
}

-- Create default callbacks for all input callback names
for index, name in ipairs(inputCallbackNames) do
    inputCallbackNames[name] = index
    if not defaultInputCallbacks[name] then
        defaultInputCallbacks[name] = function(self, ...)
            local internal = object.getInternal(self)
            if internal.active and internal.active.isEnabled then
                internal.active[name](internal.active, ...)
                return true
            end
            return false
        end
    end
end

-- LOVE2D input hook functions
local function hookMouseInput()
    local old = {
        mousepressed = love.mousepressed or function() end,
        mousemoved = love.mousemoved or function() end,
        mousereleased = love.mousereleased or function() end,
        wheelmoved = love.wheelmoved or function() end
    }
    
    love.mousepressed = function(x, y, button, isTouch)
        if button and not isTouch and inputState.root then
            inputState.root:keypressed(("mouse%d"):format(button))
        end
        if button and not isTouch and inputState.root and inputState.root:check(x, y) and inputState.root:pressed(x, y, button) ~= false then
            return
        end
        old.mousepressed(x, y, button, isTouch)
    end
    
    love.mousemoved = function(x, y, dx, dy, isTouch)
        if love.mouse.getRelativeMode() and inputState.root then
            inputState.root:mousedelta(dx, dy)
            return
        end
        if not isTouch and inputState.root then
            local r = false
            for i, b in ipairs(inputState.root.presses) do
                if type(b) == "number" then
                    if inputState.root:moved(x, y, dx, dy, b) then
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
        if button and not isTouch and inputState.root then
            inputState.root:keyreleased(("mouse%d"):format(button))
        end
        if button and not isTouch and inputState.root and inputState.root.presses:find(button) then
            inputState.root:released(x, y, button)
            return
        end
        old.mousereleased(x, y, button, isTouch)
    end
    
    love.wheelmoved = function(x, y)
        return inputState.root and inputState.root.isHovered and inputState.root:scrolled(y) or old.wheelmoved(x, y)
    end
end

local function hookTouchInput()
    local old = {
        touchpressed = love.touchpressed or function() end,
        touchmoved = love.touchmoved or function() end,
        touchreleased = love.touchreleased or function() end
    }
    
    love.touchpressed = function(id, x, y)
        if inputState.root and inputState.root:check(x, y) and inputState.root:pressed(x, y, id) ~= false then
            return
        end
        old.touchpressed(id, x, y)
    end
    
    love.touchmoved = function(id, x, y, dx, dy)
        if inputState.root and inputState.root.presses:find(id) and inputState.root:moved(x, y, dx, dy, id) then
            return
        end
        old.touchmoved(id, x, y, dx, dy)
    end
    
    love.touchreleased = function(id, x, y)
        if inputState.root and inputState.root.presses:find(id) then
            inputState.root:released(x, y, id)
            return
        end
        old.touchreleased(id, x, y)
    end
end

local function hookKeyboardInput()
    local old = {
        keypressed = love.keypressed or function() end,
        keyreleased = love.keyreleased or function() end,
        textinput = love.textinput or function() end
    }
    
    love.keypressed = function(key, scancode, isrepeat)
        if inputState.root and inputState.root:keypressed(key, scancode, isrepeat) then
            return
        end
        old.keypressed(key, scancode, isrepeat)
    end
    
    love.keyreleased = function(key, scancode)
        if inputState.root and inputState.root:keyreleased(key, scancode) then
            return
        end
        old.keyreleased(key, scancode)
    end
    
    love.textinput = function(text)
        if inputState.root and inputState.root:textinput(text) then
            return
        end
        old.textinput(text)
    end
end

-- Initialize input system
local function initInput()
    if not love then return end
    
    hookMouseInput()
    hookTouchInput()
    hookKeyboardInput()
end

-- Set root object for input handling
local function setInputRoot(obj)
    if obj ~= nil and not object.is(obj) then
        error(("Invalid object (got: %s (%s))"):format(tostring(obj), type(obj)), 2)
    end
    
    if inputState.root then
        -- Cancel all presses
        for i, p in ipairs(inputState.root.presses) do
            inputState.root:cancelled(p)
        end
        inputState.root:deactivated()
    end
    
    inputState.root = obj
    
    if obj then
        obj:activated()
    end
end

return {
    init = initInput,
    setRoot = setInputRoot,
    getRoot = function() return inputState.root end,
    callbackNames = inputCallbackNames,
    properties = inputProperties,
    methods = inputMethods,
    defaultCallbacks = defaultInputCallbacks
} 