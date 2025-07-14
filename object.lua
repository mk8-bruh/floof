local class = require("class")

-- callback list
Object.callbackNames, Object.activeCallbackNames = {
    "resize", "update", "predraw", "draw", "postdraw", "quit",
    "pressed", "moved", "released", "cancelled", "scrolled",
    "hovered", "unhovered", "activated", "deactivated",
    "enabled", "disabled", "added", "removed", "addedto", "removedfrom",
    "childactivated", "childdeactivated", "message"
}, {
    "keypressed", "keyreleased", "textinput", "mousepressed", "mousereleased",
    "mousemoved", "wheelmoved", "touchpressed", "touchreleased", "touchmoved",
    "gamepadpressed", "gamepadreleased", "gamepadaxis", "joystickpressed",
    "joystickreleased", "joystickaxis", "joystickhat", "joystickball",
    "filedropped", "directorydropped", "lowmemory", "threaderror"
}

-- Create callback name lookup tables
for i, n in ipairs(Object.callbackNames) do
    Object.callbackNames[n] = i
end
for i, n in ipairs(Object.activeCallbackNames) do
    Object.activeCallbackNames[n] = i
end

local Object = class("Object")

-- Global root object
Object.root = nil

function Object.setRoot(obj)
    if obj ~= nil and not class.isInstance(obj, Object) then
        error(("Invalid object (got: %s (%s))"):format(tostring(obj), type(obj)), 2)
    end
    if Object.root then
        -- cancel all presses
        for i, p in ipairs(Object.root._presses) do
            Object.root:cancelled(p)
        end
        Object.root:deactivated()
    end
    Object.root = obj
    if obj then
        obj:activated()
    end
end

-- Properties

Object:getter("parent", function(self) return self._parent end)

Object:setter("parent", function(self, value)
    if self._parent == value then return end
    if value ~= nil and not class.isInstance(value, Object) then
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

Object:getter("children", function(self) 
    local children = {}
    for i, e in ipairs(self._children) do
        table.insert(children, e)
    end
    return children
end)

Object:setter("children", function(self, value)
    -- shorthand for setting this object as parent to each of the objects
    if type(value) ~= "table" then
        error(("Value must be a table of objects (got:  %s (%s))"):format(tostring(value), type(value)), 3)
    end
    for i, v in ipairs(value) do
        if not class.isInstance(v, Object) then
            error(("Non-object value at index %d: %s (%s)"):format(i, tostring(v), type(v)), 3)
        end
        if self:isChildOf(v) then
            error(("Cannot assign object as a child of its child"), 3)
        end
        v.parent = self
    end
end)

Object:getter("z", function(self) return self._z end)

Object:setter("z", function(self, value)
    if type(value) ~= "number" then
        error(("Z value must be a number (got: %s (%s))"):format(tostring(value), type(value)), 3)
    end
    self._z = value
    if self._parent then self._parent:refreshChildren() end
end)

Object:getter("enabledSelf", function(self) return self._enabled end)

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

Object:getter("activeChild", function(self) return self._active end)

Object:setter("activeChild", function(self, value)
    if self._active == value then return end
    if not class.isInstance(value, Object) and value ~= nil then
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
    local x, y = love.mouse.getPosition()
    for i, e in ipairs(self.children) do
        if e.isEnabled and e:check(x, y) then
            return e
        end
    end
end)

Object:getter("isHovered", function(self)
    if self == Object.root then
        return self:check(love.mouse.getPosition())
    end
    return self._parent and self._parent.isHovered and self._parent.hoveredChild == self or false
end)

Object:getter("isPressed", function(self)
    return #self._presses > 0
end)

Object:getter("press", function(self)
    return self._presses[#self._presses]
end)

Object:getter("indexes", function(self) return self._indexes end)

-- Constructor
function Object:init(data)
    self._parent = nil
    self._children = {}
    self._childRegister = {}
    self._z = 0
    self._enabled = true
    self._active = nil
    self._presses = {}
    self._pressedObject = {}
    self._callbacks = {}
    self._check = nil
    self._lastHovered = nil
    self._indexes = {}
    self._getters = {}
    self._setters = {}
    self._meta = {}

    for k, v in pairs(data) do
        self[k] = v
    end
    
    -- Set parent to root if not specified
    if not self._parent and Object.root then
        self.parent = Object.root
    end
    
    -- Initialize screen dimensions
    self:resize(love.graphics.getDimensions())
end

-- Object methods

function Object:updateChildStatus(object)
    if not class.isInstance(object, Object) then
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
    self._children = {}
    for c in pairs(self._childRegister) do
        table.insert(self._children, c)
    end
    table.sort(self._children, function(a, b) return a._z > b._z end)
end

function Object:isChildOf(object)
    if not class.isInstance(object, Object) then
        error(("Invalid object (got: %s (%s))"):format(tostring(object), type(object)), 3)
    end
    local e = self._parent
    while e do
        if e == object then return true end
        e = e._parent
    end
    return false
end

-- Generalized position grabber (touch/mouse)
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

function Object:setPressTarget(id, object)
    if object ~= nil and not class.isInstance(object, Object) then
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
        i = #self._presses
    end
    if not self._presses[i] then
        error(("Invalid index (got: %s (%s))"):format(tostring(i), type(i)), 3)
    end
    return getPressPosition(self._presses[i])
end

-- Convenience methods

function Object:addChild(child)
    if not class.isInstance(child, Object) then
        error(("Invalid object (got: %s (%s))"):format(tostring(child), type(child)), 3)
    end
    child.parent = self
    return child
end

function Object:removeChild(child)
    if not class.isInstance(child, Object) then
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
    if Object.callbackNames[message] or self[message] then
        error(("Cannot send reserved message: %q"):format(message), 2)
    end
    
    for i, child in ipairs(self._children) do
        if child.isEnabled and type(child[message]) == "function" then
            child[message](child, ...)
        end
    end
end

function Object:broadcast(message, ...)
    if Object.callbackNames[message] or self[message] then
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

-- Callbacks

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

function Object:draw()
    -- custom 'draw' callback that restores the state for neater graphics code
    local pre, draw, post =
        self._callbacks.predraw or (self.class ~= Object and self.class.predraw),
        self._callbacks.draw or (self.class ~= Object and self.class.draw),
        self._callbacks.postdraw or (self.class ~= Object and self.class.postdraw)
    
    love.graphics.push("all")
    if pre then
        pre(self)
    end
    
    local drawn = false
    for i = #self._children, 1, -1 do
        local e = self._children[i]
        if e._z >= 0 and not drawn then
            if not drawn and draw then
                draw(self)
            end
            drawn = true
        end
        if e.isEnabled then
            love.graphics.push("all")
            e:draw()
            love.graphics.pop()
        end
    end
    
    if not drawn and draw then
        draw(self)
    end
    
    if post then
        post(self)
    end
    
    love.graphics.pop()
end

function Object:pressed(x, y, id)
    table.insert(self._presses, id)
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
            table.remove(self._presses, i)
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
            table.remove(self._presses, i)
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

-- Additional callback methods
function Object:hovered()
    -- Called when mouse enters the object
end

function Object:unhovered()
    -- Called when mouse leaves the object
end

function Object:activated()
    -- Called when object becomes active
end

function Object:deactivated()
    -- Called when object becomes inactive
end

function Object:enabled()
    -- Called when object is enabled
end

function Object:disabled()
    -- Called when object is disabled
end

function Object:added(parent)
    -- Called when object is added to a parent
end

function Object:removed(parent)
    -- Called when object is removed from a parent
end

function Object:addedto(parent)
    -- Called when object is added to a specific parent
end

function Object:removedfrom(parent)
    -- Called when object is removed from a specific parent
end

function Object:childactivated(child)
    -- Called when a child becomes active
end

function Object:childdeactivated(child)
    -- Called when a child becomes inactive
end

function Object:message(msg, ...)
    -- Called when object receives a message
end

for i, n in ipairs(Object.activeCallbackNames) do
    Object[n] = function(self, ...)
        if self._active and self._active.isEnabled then
            self._active[n](self._active, ...)
            return true
        end
        return false
    end
end

for i, n in ipairs(Object.callbackNames) do
    if not Object[n] then
        Object[n] = function(self, ...)
            local f = self._callbacks[n] or (self.class ~= Object and self.class[n])
            if f then return f(self, ...) end
        end
    end
end

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
        for i, child in ipairs(self.children) do
            if child:check(x, y) then
                return true
            end
        end
        return false
    end
}
Object.checks.default = Object.checks.cornerRect

-- Check function
function Object:check(x, y)
    return self._check and self._check(self, x, y) or 
           self.class and self.class.check and self.class.check(self, x, y) or
           Object.checks.default(self, x, y)
end

-- __set metamethod for callback proxy
Object:meta("set", function(self, k, v)
    if Object.callbackNames[k] then
        if type(v) == "function" then
            self._callbacks[k] = v
        elseif type(v) == "boolean" then
            self._callbacks[k] = function() return v end
        elseif v == nil then
            self._callbacks[k] = nil
        else
            error(("Callback value must be a function or boolean (got: %s (%s))"):format(tostring(v), type(v)), 2)
        end
    else
        rawset(self, k, v)
    end
end)

return Object