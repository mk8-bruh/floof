local class = require("class")
local Array = require("array")

local emptyf = function(...) return end

-- Object class definition
local Object = class("Object")

-- Class-level constants and state
Object.callbackNames = {
    "resize", "update", "predraw", "draw", "postdraw", "quit",
    "pressed", "moved", "released", "cancelled",
    "scrolled", "hovered", "unhovered",
    "mousedelta", "keypressed", "keyreleased", "textinput",
    "filedropped", "directorydropped",
    "joystickadded", "joystickremoved",
    "joystickaxis", "joystickhat", "joystickpressed", "joystickreleased",
    "gamepadaxis", "gamepadpressed", "gamepadreleased",
    "created", "deleted", "added", "removed", "addedto", "removedfrom",
    "activated", "deactivated", "childactivated", "childdeactivated",
    "enabled", "disabled",
}

Object.activeCallbackNames = {
    "mousedelta", "keypressed", "keyreleased", "textinput",
    "filedropped", "directorydropped",
    "joystickadded", "joystickremoved",
    "joystickaxis", "joystickhat", "joystickpressed", "joystickreleased",
    "gamepadaxis", "gamepadpressed", "gamepadreleased"
}

-- LÖVE callback constants
Object.loveCallbackNames = {
    "resize", "update", "draw", "quit",
    "mousepressed", "mousereleased", "mousemoved", "wheelmoved",
    "touchpressed", "touchreleased", "touchmoved", "touchcancelled",
    "keypressed", "keyreleased", "textinput",
    "filedropped", "directorydropped",
    "joystickadded", "joystickremoved",
    "joystickaxis", "joystickhat", "joystickpressed", "joystickreleased",
    "gamepadaxis", "gamepadpressed", "gamepadreleased"
}

Object.blockingCallbackNames = {
    "keypressed", "keyreleased", "textinput",
    "filedropped", "directorydropped",
    "joystickadded", "joystickremoved",
    "joystickaxis", "joystickhat", "joystickpressed", "joystickreleased",
    "gamepadaxis", "gamepadpressed", "gamepadreleased"
}

-- Convert to lookup tables
for i, n in ipairs(Object.callbackNames) do
    Object.callbackNames[n] = i
end

for i, n in ipairs(Object.activeCallbackNames) do
    Object.activeCallbackNames[n] = i
end

-- Root object reference
Object.root = nil

function Object.setRoot(obj)
    if obj ~= nil and not Object:isClassOf(obj) then
        error(("Invalid object (got: %s (%s))"):format(tostring(obj), type(obj)), 2)
    end
    if Object.root then
        -- cancel all presses
        for i, p in ipairs(Object.root.presses) do
            Object.root:cancelled(p)
        end
        Object.root:deactivated()
    end
    Object.root = obj
    if obj then
        obj:activated()
    end
end

-- Generalized position grabber (touch/mouse)
local function getPressPosition(id)
    if type(id) == "number" and love and love.mouse then
        return love.mouse.getPosition()
    elseif love and love.touch then
        local s, x, y = pcall(love.touch.getPosition, id)
        if s then
            return x, y
        end
    end
end

-- Constructor
function Object:init(data)
    self.callbacks = {}
    
    self._parent = nil
    self._children = Array()
    self._childRegister = {}
    self._z = 0
    self._enabled = true
    self._active = nil
    self._presses = Array()
    self._pressedObject = {}
    self._check = nil
    self._lastHovered = nil
    
    if data then
        for k, v in pairs(data) do
            self[k] = v
        end
    end
    
    if not self._parent and Object.root then
        self.parent = Object.root
    end
    
    -- Only call resize if love.graphics is available
    if love and love.graphics then
        self:resize(love.graphics.getDimensions())
    end
end

function Object:setup()
    self.callbacks = {}
end

-- Core callback implementations
Object.callbacks = {}
function Object:__set(k, v)
    if Object.callbackNames[k] then
        if self == Object then
            Object.callbacks[k] = v
        else
            self.callbacks = self.callbacks or {}
            self.callbacks[k] = v
        end
    else
        rawset(self, k, v)
    end
end

function Object:getCallback(k)
    local f, c = self.callbacks and self.callbacks[k], self.class
    while c and c ~= Object and not f do
        f = c.callbacks and c.callbacks[k]
        c = c.super
    end
    return f or emptyf
end

Object.wrappers = {}
function Object:__get(k)
    if Object.callbackNames[k] then
        if not Object.wrappers[k] then
            Object.wrappers[k] = function(self, ...)
                if not Object:isClassOf(self) then error(("Function %q must be called on an object (got: %s (%s))"):format(k, tostring(self), type(self)), 2) end
                local old = Object.callbacks[k] or emptyf
                local f = self:getCallback(k)
                local v = f and f(self, ...)
                if k == "moved" then
                    local r = old(self, ...)
                    return v or r
                elseif k == "pressed" or k == "released" or Object.activeCallbackNames[k] then
                    return (v ~= false) and old(self, ...)
                else
                    old(self, ...)
                    return v
                end
            end
        end
        return Object.wrappers[k]
    end
end

function Object:resize(w, h)
    for i, e in ipairs(self._children) do
        e:resize(w, h)
    end
end

function Object:update(dt)
    for i, e in ipairs(self._children) do
        if e.isEnabled then
            e:update(dt)
        end
    end
    if self._lastHovered ~= self.hoveredChild then
        if self._lastHovered then
            self._lastHovered:unhovered()
        end
        if self.hoveredChild then
            self.hoveredChild:hovered()
        end
        self._lastHovered = self.hoveredChild
    end
end

function Object:quit()
    for i, e in ipairs(self._children) do
        e:quit()
    end
end

function Object:pressed(x, y, id)
    self._presses:append(id)
    for i, e in ipairs(self._children) do
        if e.isEnabled and e:check(x, y) and e:pressed(x, y, id) ~= false then
            self._pressedObject[id] = e
            return true
        end
    end
end

function Object:moved(x, y, dx, dy, id)
    if self._pressedObject[id] then
        if self._pressedObject[id]:moved(x, y, dx, dy, id) ~= true and not self._pressedObject[id]:check(x, y) then
            -- object should no longer be pressed
            self:setPressTarget(id)
        end
        return true
    end
end

function Object:released(x, y, id)
    for i, p in ipairs(self._presses) do
        if p == id then
            self._presses:pop(i)
            break
        end
    end
    if self._pressedObject[id] then
        self._pressedObject[id]:released(x, y, id)
        self._pressedObject[id] = nil
        return true
    end
end

function Object:cancelled(id)
    for i, p in ipairs(self._presses) do
        if p == id then
            self._presses:pop(i)
            break
        end
    end
    if self._pressedObject[id] then
        self._pressedObject[id]:cancelled(id)
        self._pressedObject[id] = nil
    end
end

function Object:scrolled(t)
    if self.isHovered and self.hoveredChild then
        self.hoveredChild:scrolled(t)
        return true
    end
end

-- Active callback implementations
for i, n in ipairs(Object.activeCallbackNames) do
    Object[n] = function(self, ...)
        if self._active and self._active.isEnabled then
            self._active[n](self._active, ...)
            return true
        end
        return false
    end
end

Object.wrappers.draw = function(self, ...)
    if not Object:isClassOf(self) then error(("Function \"draw\" must be called on an object (got: %s (%s))"):format(tostring(self), type(self)), 2) end
    local pre, draw, post = self:getCallback("predraw"), self:getCallback("draw"), self:getCallback("postdraw")
    if love and love.graphics then
        love.graphics.push("all")
    end
    if pre then
        pre(self, ...)
    end
    local drawn = false
    for i = #self._children, 1, -1 do
        local e = self._children[i]
        if e._z >= 0 and not drawn then
            if not drawn and draw then
                draw(self, ...)
            end
            drawn = true
        end
        if e.isEnabled then
            if love and love.graphics then
                love.graphics.push("all")
            end
            e:draw(...)
            if love and love.graphics then
                love.graphics.pop()
            end
        end
    end
    if not drawn and draw then
        draw(self, ...)
    end
    if post then
        post(self, ...)
    end
    if love and love.graphics then
        love.graphics.pop()
    end
end

-- Object methods
function Object:updateChildStatus(object)
    if not Object:isClassOf(object) then
        error(("Invalid object (got: %s (%s))"):format(tostring(object), type(object)), 3)
    end
    if object._parent == self then
        self._childRegister[object] = true
    else
        self._childRegister[object] = nil
        for i, id in ipairs(object._presses) do
            self._pressedObject[id] = nil
        end
    end
    self:refreshChildren()
end

function Object:refreshChildren()
    self._children = Array()
    for c in pairs(self._childRegister) do
        self._children:append(c)
    end
    self._children:sort(function(a, b) return a._z > b._z end)
end

function Object:isChildOf(object)
    if not Object:isClassOf(object) then
        error(("Invalid object (got: %s (%s))"):format(tostring(object), type(object)), 3)
    end
    local e = self._parent
    while e do
        if e == object then return true end
        e = e._parent
    end
    return false
end

function Object:setPressTarget(id, object)
    if object ~= nil and not Object:isClassOf(object) then
        error(("Invalid object (got: %s (%s))"):format(tostring(object), type(object)), 3)
    end
    if object ~= nil and object._parent ~= self then
        error(("Target must be a child of this object"), 3)
    end
    local p = self._pressedObject[id]
    if p == object then return end
    if p then
        p:cancelled(id)
    end
    local x, y = getPressPosition(id)
    if object and object:pressed(x, y, id) ~= false then
        self._pressedObject[id] = object
    else
        self._pressedObject[id] = nil
    end
end

function Object:getPressPosition(i)
    if i == nil then
        i = self._presses.length
    end
    if not self._presses[i] then
        error(("Invalid index (got: %s (%s))"):format(tostring(i), type(i)), 3)
    end
    return getPressPosition(self._presses[i])
end

-- Convenience methods
function Object:addChild(child)
    if not Object:isClassOf(child) then
        error(("Invalid object (got: %s (%s))"):format(tostring(child), type(child)), 3)
    end
    child.parent = self
    return child
end

function Object:removeChild(child)
    if not Object:isClassOf(child) then
        error(("Invalid object (got: %s (%s))"):format(tostring(child), type(child)), 3)
    end
    if child._parent == self then
        child.parent = nil
    end
    return child
end

function Object:setParent(parent)
    self.parent = parent
    return self
end

-- Messaging system
function Object:send(message, ...)
    if Object[message] then
        error(("Cannot send reserved message: %q"):format(message), 2)
    end
    
    for i, child in ipairs(self._children) do
        if child.isEnabled and type(child[message]) == "function" then
            child[message](child, ...)
        end
    end
end

function Object:broadcast(message, ...)
    if Object[message] then
        error(("Cannot broadcast reserved message: %q"):format(message), 2)
    end
    
    for i, child in ipairs(self._children) do
        if child.isEnabled then
            if type(child[message]) == "function" then
                child[message](child, ...)
            end
            child:broadcast(message, ...)
        end
    end
end

-- Property getters and setters
Object:getter("parent", function(self)
    return self._parent
end)

Object:setter("parent", function(self, value)
    if self._parent == value then return end
    if value ~= nil and not Object:isClassOf(value) then
        error(("Parent must be an object (got: %s (%s))"):format(tostring(value), type(value)), 3)
    end
    if self == value then
        error(("Cannot assign object as its own parent"), 3)
    end
    if value and value:isChildOf(self) then
        error(("Cannot assign object as the parent of its current parent"), 3)
    end
    -- deactivate in all parent objects
    local e = self._parent
    while e do
        if value and value:isChildOf(e) then break end
        if e.activeChild == self then
            e.activeChild = nil
        end
        e = e._parent
    end
    -- cancel all presses
    for i, p in ipairs(self._presses) do
        self:cancelled(p)
        self._parent:setPressTarget(p)
    end
    local p = self._parent
    self._parent = value
    if p then
        p:updateChildStatus(self)
        p:removed(self)
        self:removedfrom(p)
    end
    if value then
        value:updateChildStatus(self)
        value:added(self)
        self:addedto(value)
    end
end)

Object:getter("z", function(self)
    return self._z
end)

Object:setter("z", function(self, value)
    if type(value) ~= "number" then
        error(("Z value must be a number (got: %s (%s))"):format(tostring(value), type(value)), 3)
    end
    self._z = value
    if self._parent then self._parent:refreshChildren() end
end)

Object:getter("enabledSelf", function(self)
    return self._enabled
end)

Object:setter("enabledSelf", function(self, value)
    if type(value) ~= "boolean" then
        error(("Enabled state must be a boolean value (got: %s (%s))"):format(tostring(value), type(value)), 3)
    end
    if self._enabled == value then return end
    self._enabled = value
    if value then
        self:enabled()
    else
        self:disabled()
        for i, p in ipairs(self._presses) do
            self:cancelled(p)
            self._parent:setPressTarget(p)
        end
    end
end)

Object:getter("isEnabled", function(self)
    if not self._enabled then
        return false
    elseif self._parent then
        return self._parent.isEnabled
    end
    return true
end)

Object:getter("activeChild", function(self)
    return self._active
end)

Object:setter("activeChild", function(self, value)
    if self._active == value then return end
    if not Object:isClassOf(value) and value ~= nil then
        error(("Active child must be an object (got: %s (%s))"):format(tostring(value), type(value)), 3)
    end
    if value ~= nil and not value:isChildOf(self) then
        error(("Active child must be a child of the object"), 3)
    end
    local inRoot = Object.root and (self == Object.root or self:isChildOf(Object.root))
    if inRoot and self._active then
        self._active:deactivated()
        self:childdeactivated(self._active)
    end
    self._active = value
    if inRoot and value then
        value:activated()
        self:childactivated(value)
    end
end)

Object:getter("isActive", function(self)
    if self == Object.root then return true end
    local e = self._parent
    while e do
        if e.activeChild == self then
            return true
        end
        if e == Object.root then break end
        e = e._parent
    end
    return false
end)

Object:getter("hoveredChild", function(self)
    if not self.isHovered then return end
    if love and love.mouse then
        local x, y = love.mouse.getPosition()
        for i, e in ipairs(self._children) do
            if e.isEnabled and e:check(x, y) then
                return e
            end
        end
    end
end)

Object:getter("isHovered", function(self)
    if self == Object.root then
        return love and love.mouse and self:check(love.mouse.getPosition())
    end
    return self._parent and self._parent.isHovered and self._parent.hoveredChild == self or false
end)

Object:getter("pressedObject", function(self)
    return setmetatable({}, {
        __index = self._pressedObject,
        __newindex = function(t, k, v)
            if not getPressPosition(k) then
                error(("Invalid press ID: %s (%s)"):format(tostring(k), type(k)), 3)
            end
            if v ~= nil and not Object.is(v) then
                error(("Invalid object (got: %s (%s))"):format(tostring(v), type(v)), 3)
            end
            if v ~= nil and v._parent ~= self then
                error(("Target must be a child of this object"), 2)
            end
            self:setPressTarget(k, v)
        end
    })
end)

Object:getter("children", function(self)
    return self._children:copy()
end)

Object:getter("presses", function(self)
    return self._presses:copy()
end)

Object:getter("press", function(self)
    return self._presses[-1]
end)

Object:getter("isPressed", function(self)
    return self._presses.length > 0
end)

-- Check function
function Object:check(x, y)
    if self._check then
        return self._check(self, x, y)
    elseif self.class and self.class.check ~= Object.check then
        return self.class.check(self, x, y)
    else
        return Object.checks.default(self, x, y)
    end
end

Object:setter("check", function(self, value)
    if type(value) == "boolean" then
        value = function() return value end
    end
    if type(value) ~= "function" then
        error(("Check function must be a function (got: %s (%s))"):format(tostring(value), type(value)), 3)
    end
    self._check = value
end)

Object:getter("check", function(self)
    return Object.check
end)

-- Pre-defined checking functions
Object.checks = {
    -- rectangle with top-left origin (common for LÖVE)
    cornerRect = function(self, x, y)
        if type(self.x) ~= "number" or type(self.y) ~= "number" or type(self.w) ~= "number" or type(self.h) ~= "number" then
            return false
        end
        local l, t, r, b = math.min(self.x, self.x + self.w), math.min(self.y, self.y + self.h), math.max(self.x, self.x + self.w), math.max(self.y, self.y + self.h)
        return x >= l and x <= r and y >= t and y <= b
    end,
    -- rectangle with center origin (common for normal people)
    centerRect = function(self, x, y)
        if type(self.x) ~= "number" or type(self.y) ~= "number" or type(self.w) ~= "number" or type(self.h) ~= "number" then
            return false
        end
        return x >= self.x - self.w/2 and x <= self.x + self.w/2 and y >= self.y - self.h/2 and y <= self.y + self.h/2
    end,
    -- circle with center origin
    circle = function(self, x, y)
        if type(self.x) ~= "number" or type(self.y) ~= "number" or type(self.r) ~= "number" then
            return false
        end
        return (x - self.x)^2 + (y - self.y)^2 <= self.r^2
    end,
    -- ellipse with center origin
    ellipse = function(self, x, y)
        if type(self.x) ~= "number" or type(self.y) ~= "number" or type(self.w) ~= "number" or type(self.h) ~= "number" then
            return false
        end
        return (x - self.x)^2 / (self.w/2)^2 + (y - self.y)^2 / (self.h)/2^2 <= 1
    end,
    -- union of all child checks
    children = function(self, x, y)
        for i, child in ipairs(self._children) do
            if child:check(x, y) then
                return true
            end
        end
        return false
    end
}
Object.checks.default = Object.checks.cornerRect

-- LÖVE callback setup function
function Object.registerCallbacks(root)
    if not love then return end
    if root and not Object:isClassOf(root) then
        error(("Invalid root object: %s (%s)"):format(tostring(root), type(root)), 3)
    end
    
    local emptyf = function(...) return end
    
    local old = {}
    for _, f in ipairs(Object.loveCallbackNames) do
        old[f] = love[f] or emptyf
    end
    
    for _, f in ipairs(Object.blockingCallbackNames) do
        love[f] = function(...)
            return (root or Object.root) and (root or Object.root)[f]((root or Object.root), ...) or old[f](...)
        end
    end
    
    for _, f in ipairs{"resize", "update", "draw", "quit"} do
        love[f] = function(...)
            old[f](...)
            if (root or Object.root) then
                (root or Object.root)[f]((root or Object.root), ...)
            end
        end
    end
    
    love.mousepressed = function(...)
        local x, y, b, t = ...
        if b and not t and (root or Object.root) then
            (root or Object.root):keypressed(("mouse%d"):format(b))
        end
        if b and not t and (root or Object.root) and (root or Object.root):check(x, y) and (root or Object.root):pressed(x, y, b) ~= false then
            return
        end
        old.mousepressed(...)
    end
    
    love.mousemoved = function(...)
        local x, y, dx, dy, t = ...
        if love and love.mouse and love.mouse.getRelativeMode() and (root or Object.root) then
            (root or Object.root):mousedelta(dx, dy)
            return
        end
        if not t and (root or Object.root) then
            local r = false
            for i, b in ipairs((root or Object.root).presses) do
                if type(b) == "number" then
                    if (root or Object.root):moved(x, y, dx, dy, b) then
                        r = true
                    end
                end
            end
            if r then
                return
            end
        end
        old.mousemoved(...)
    end
    
    love.mousereleased = function(...)
        local x, y, b, t = ...
        if b and not t and (root or Object.root) then
            (root or Object.root):keyreleased(("mouse%d"):format(b))
        end
        if b and not t and (root or Object.root) then
            for i, press in ipairs((root or Object.root).presses) do
                if press == b then
                    (root or Object.root):released(x, y, b)
                    return
                end
            end
        end
        old.mousereleased(...)
    end
    
    love.wheelmoved = function(...)
        local x, y = ...
        return (root or Object.root) and (root or Object.root).isHovered and (root or Object.root):scrolled(y) or old.wheelmoved(...)
    end
    
    love.touchpressed = function(...)
        local id, x, y = ...
        if (root or Object.root) and (root or Object.root):check(x, y) and (root or Object.root):pressed(x, y, id) ~= false then
            return
        end
        old.touchpressed(...)
    end
    
    love.touchmoved = function(...)
        local id, x, y, dx, dy = ...
        if (root or Object.root) then
            for i, press in ipairs((root or Object.root).presses) do
                if press == id then
                    if (root or Object.root):moved(x, y, dx, dy, id) then
                        return
                    end
                    break
                end
            end
        end
        old.touchmoved(...)
    end
    
    love.touchreleased = function(...)
        local id, x, y = ...
        if (root or Object.root) then
            for i, press in ipairs((root or Object.root).presses) do
                if press == id then
                    (root or Object.root):released(x, y, id)
                    return
                end
            end
        end
        old.touchreleased(...)
    end
end

Object.serializeFields = {
    "z", "parent", "isPressed", "presses",
    "isEnabled", "enabledSelf", "isActive", "isHovered",
    "activeChild", "hoveredChild", "children"
}

Object.serializeIndent = 4

function Object:serialize(indent)
    local str = tostring(self) .. ":"
    local ind = string.rep(" ", Object.serializeIndent * ((indent or 0) + 1))
    if rawget(self, "serializeFields") then
        for i, f in ipairs(self.serializeFields) do
            local value = self[f]
            if value ~= nil then
                str = str .. ("\n%s%s: %s"):format(ind, f, tostring(value))
            end
        end
    end
    local c = self.class
    while c do
        if Array:isClassOf(c.serializeFields) then
            for i, f in c.serializeFields:iterate() do
                if type(f) == "string" then
                    local value = self[f]
                    if value ~= nil then
                        str = str .. ("\n%s%s: %s"):format(ind, f, tostring(value))
                    end
                end
            end
        end
        c = c.class or c.super
    end
    return str
end

Object.root = Object({check = true})

return Object