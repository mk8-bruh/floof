local _PATH = (...):match("(.-)[^%.]+$")
local module, inj = {}, {} -- dependency injection table

-- dummy functions
local emptyf    = function(...) return end
local identityf = function(...) return ... end
local setk      = function(t, k, v) t[k] = v end

-- recursively traverse a list of index metas
local function _index(indexes, t, k, visited)
    for i, index in ipairs(indexes) do
        local v
        if type(index) == "table" then
            v = index[k]
        elseif type(index) == "function" then
            local s, e = pcall(index, t, k)
            if not s then error(("Error while trying to access field %s (layer %d, %s): %s"):format(type(k) == "string" and '"'..k..'"' or tostring(k), i, tostring(index), e), 3) else v = e end
        end
        if v ~= nil then return v end
    end
end

-- generalized position grabber (touch/mouse)
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

-- callback list
module.callbackNames, module.activeCallbackNames = {
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
}, {
    "mousedelta", "keypressed", "keyreleased", "textinput",
    "filedropped", "directorydropped",
    "joystickadded", "joystickremoved",
    "joystickaxis", "joystickhat", "joystickpressed", "joystickreleased",
    "gamepadaxis", "gamepadpressed", "gamepadreleased"
}

-- object identification
local objects = setmetatable({}, {__mode = "k"})
function module.is(value) return value and objects[value] ~= nil end

function module.setRoot(obj)
    if obj ~= nil and not module.is(obj) then
        error(("Invalid object (got: %s (%s))"):format(tostring(obj), type(obj)), 2)
    end
    if module.root then
        -- cancel all presses
        for i, p in ipairs(module.root.presses) do
            module.root:cancelled(p)
        end
        module.root:deactivated()
    end
    module.root = obj
    if obj then
        obj:activated()
    end
end

-- unique object callbacks
local objectCallbacks = {
    resize = function(self, w, h)
        for i, e in ipairs(self.children) do
            e:resize(w, h)
        end
    end,
    update = function(self, dt)
        local internal = objects[self].internal
        for i, e in ipairs(self.children) do
            if e.isEnabled then
                e:update(dt)
            end
        end
        if internal.lastHovered ~= self.hoveredChild then
            if internal.lastHovered then
                internal.lastHovered:unhovered()
            end
            if self.hoveredChild then
                self.hoveredChild:hovered()
            end
            internal.lastHovered = self.hoveredChild
        end
    end,
    quit = function(self)
         for i, e in ipairs(self.children) do
            e:quit()
        end
    end,
    draw = function(self)
        if not module.is(self) then error(("Function %q must be called on an object (got: %s (%s))"):format(n, tostring(self), type(self)), 2) end
        -- custom 'draw' callback that restores the state for neater graphics code
        local pre, draw, post =
            objects[self].callbacks.predraw  or (self.class and self.class.predraw ),
            objects[self].callbacks.draw     or (self.class and self.class.draw    ),
            objects[self].callbacks.postdraw or (self.class and self.class.postdraw)
        love.graphics.push("all")
        if pre then
            pre(self)
        end
        local drawn = false
        local internal = objects[self].internal
        local t = internal.children
        for i = #t, 1, -1 do
            local e = t[i]
            if e.z >= 0 and not drawn then
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
    end,
    pressed = function(self, x, y, id)
        local internal = objects[self].internal
        local t = internal.children
        internal.presses:append(id)
        for i, e in ipairs(t) do
            if e.isEnabled and e:check(x, y) and e:pressed(x, y, id) ~= false then
                internal.pressedObject[id] = e
                return true
            end
        end
    end,
    moved = function(self, x, y, dx, dy, id)
        local internal = objects[self].internal
        if internal.pressedObject[id] then
            if internal.pressedObject[id]:moved(x, y, dx, dy, id) ~= true and not self.pressedObject[id]:check(x, y) then
                -- object should no longer be pressed
                self:setPressTarget(id)
            end
            return true
        end
    end,
    released = function(self, x, y, id)
        local internal = objects[self].internal
        internal.presses:remove(id)
        if internal.pressedObject[id] then
            internal.pressedObject[id]:released(x, y, id)
            internal.pressedObject[id] = nil
            return true
        end
    end,
    cancelled = function(self, id)
        local internal = objects[self].internal
        internal.presses:remove(id)
        if internal.pressedObject[id] then
            internal.pressedObject[id]:cancelled(x, y, id)
            internal.pressedObject[id] = nil
        end
    end,
    scrolled = function(self, t)
        if self.isHovered and self.hoveredChild then
            self.hoveredChild:scrolled(t)
            return true
        end
    end
}

-- default callbacks called on the active element
for i, n in ipairs(module.activeCallbackNames) do
    module.activeCallbackNames[n] = i
    objectCallbacks[n] = objectCallbacks[n] or function(self, ...)
        local internal = objects[self].internal
        if internal.active and internal.active.isEnabled then
            internal.active[n](internal.active, ...)
            return true
        end
        return false
    end
end

for i, n in ipairs(module.callbackNames) do
    module.callbackNames[n] = i
    if n ~= "draw" then
        local old = objectCallbacks[n] or emptyf
        objectCallbacks[n] = function(self, ...)
            if not module.is(self) then error(("Function %q must be called on an object (got: %s (%s))"):format(n, tostring(self), type(self)), 2) end
            local f = objects[self].callbacks[n] or (self.class and self.class[n])
            local v = f and f(self, ...)
            if n == "moved" then
                local r = old(self, ...)
                return v or r
            elseif n == "pressed" or n == "released" or module.activeCallbackNames[n] then
                return (v ~= false) and old(self, ...)
            else
                old(self, ...)
                return v
            end
        end
    end
end

-- methods for object interaction (can access the internal state)
local objectFunctions = {
    -- update the status of the object in this object's register (used internally)
    updateChildStatus = function(self, object)
        if not module.is(object) then
            error(("Invalid object (got: %s (%s))"):format(tostring(object), type(object)), 3)
        end
        local internal = objects[self].internal
        if object.parent == self then
            internal.childRegister[object] = true
        else
            internal.childRegister[object] = nil
            for i, id in ipairs(object.presses) do
                internal.pressedObject[id] = nil
            end
        end
        self:refreshChildren()
    end,
    -- recalculate the child order according to z-indexes (used internally)
    refreshChildren = function(self)
        local internal = objects[self].internal
        internal.children = {}
        for c in pairs(internal.childRegister) do
            table.insert(internal.children, c)
        end
        table.sort(internal.children, function(a, b) return a.z > b.z end)
    end,
    -- traverse the hierarchy upwards and check for object
    isChildOf = function(self, object)
        if not module.is(object) then
            error(("Invalid object (got: %s (%s))"):format(tostring(object), type(object)), 3)
        end
        local e = self.parent
        while e do
            if e == object then return true end
            e = e.parent
        end
        return false
    end,
    -- change which element is interacting with a press
    setPressTarget = function(self, id, object)
        if object ~= nil and not module.is(object) then
            error(("Invalid object (got: %s (%s))"):format(tostring(object), type(object)), 3)
        end
        if object ~= nil and object.parent ~= self then
            error(("Target must be a child of this object"), 3)
        end
        local internal = objects[self].internal
        local p = internal.pressedObject[id]
        if p == object then return end
        if p then
            p:cancelled(id)
        end
        local x, y = getPressPosition(id)
        if object and object:pressed(x, y, id) ~= false then
            internal.pressedObject[id] = object
        else
            internal.pressedObject[id] = nil
        end
    end,
    -- get the position of the i-th press on this element, or the most recent press if unspecified
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

for k, f in pairs(objectFunctions) do
    objectFunctions[k] = function(self, ...)
        if not module.is(self) then error(("Function %q must be called on an object (got: %s (%s))"):format(n, tostring(self), type(self))) end
        return f(self, ...)
    end
end

-- protected properties of objects; each has an initializer, getter and setter (except for those that don't)
local objectProperties = {
    -- the object which this object is a child of
    parent = {
        get = function(self)
            local internal = objects[self].internal
            return internal.parent
        end,
        set = function(self, value)
            local internal = objects[self].internal
            if internal.parent == value then return end
            if value ~= nil and not module.is(value) then
                error(("Parent must be an object (got: %s (%s))"):format(tostring(value), type(value)), 3)
            end
            if self == value then
                error(("Cannot assign object as its own parent"), 3)
            end
            if value and value:isChildOf(self) then
                error(("Cannot assign object as the parent of its current parent"), 3)
            end
            -- deactivate in all parent objects
            local e = internal.parent
            while e do
                if value and value:isChildOf(e) then break end
                if e.activeChild == self then
                    e.activeChild = nil
                end
                e = e.parent
            end
            -- cancel all presses
            for i, p in ipairs(self.presses) do
                self:cancelled(p)
                self.parent:setPressTarget(p)
            end
            local p = internal.parent
            internal.parent = value
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
        end
    },
    -- a register of all the children of this object (used internally)
    childRegister = {
        init = function(self)
            local internal = objects[self].internal
            internal.childRegister = {}
        end
    },
    -- a list of this component's children sorted from front to back
    children = {
        init = function(self)
            local internal = objects[self].internal
            internal.children = inj.array.new()
        end,
        get = function(self)
            local internal = objects[self].internal
            local children = inj.array.new()
            for i, e in ipairs(internal.children) do
                table.insert(children, e)
            end
            return children
        end,
        set = function(self, value)
            -- shorthand for setting this object as parent to each of the objects
            if type(value) ~= "table" then
                error(("Value must be a table of objects (got:  %s (%s))"):format(tostring(value), type(value)), 3)
            end
            for i, v in ipairs(value) do
                if not module.is(v) then
                    error(("Non-object value at index %d: %s (%s)"):format(i, tostring(v), type(v)), 3)
                end
                if self.isChildOf(v) then
                    error(("Cannot assign object as a child of its child"), 3)
                end
                v.parent = self
            end
        end
    },
    -- the Z-sorting index
    z = {
        init = function(self)
            local internal = objects[self].internal
            internal.z = 0
        end,
        get = function(self)
            local internal = objects[self].internal
            return internal.z
        end,
        set = function(self, value)
            local internal = objects[self].internal
            if type(value) ~= "number" then
                error(("Z value must be a number (got: %s (%s))"):format(tostring(value), type(value)), 3)
            end
            internal.z = value
            if self.parent then self.parent:refreshChildren() end
        end
    },
    -- whether the object is currently enabled for receiving callbacks
    enabledSelf = {
        init = function(self)
            local internal = objects[self].internal
            internal.enabled = true
        end,
        get = function(self)
            local internal = objects[self].internal
            return internal.enabled
        end,
        set = function(self, value)
            if type(value) ~= "boolean" then
                error(("Enabled state must be a boolean value (got: %s (%s))"):format(tostring(value), type(value)), 3)
            end
            local internal = objects[self].internal
            if internal.enabled == value then return end
            internal.enabled = value
            if value then
                self:enabled()
            else
                self:disabled()
                for i, p in ipairs(self.presses) do
                    self:cancelled(p)
                    self.parent:setPressTarget(p)
                end
            end
        end
    },
    -- the global enabled state of the object
    isEnabled = {
        get = function(self)
            local internal = objects[self].internal
            if not internal.enabled then
                return false
            elseif internal.parent then
                return internal.parent.isEnabled
            end
            return true
        end
    },
    -- the currently active child of this object (dosn't have to be a direct child)
    activeChild = {
        get = function(self)
            local internal = objects[self].internal
            return internal.active
        end,
        set = function(self, value)
            local internal = objects[self].internal
            if internal.active == value then return end
            if not module.is(value) and value ~= nil then
                error(("Active child must be an object (got: %s (%s))"):format(tostring(value), type(value)), 3)
            end
            if value ~= nil and not value:isChildOf(self) then
                error(("Active child must be a child of the object"), 3)
            end
            local inRoot = module.root and (self == module.root or self:isChildOf(module.root))
            if inRoot and internal.active then
                internal.active:deactivated()
                self:childdeactivated(internal.active)
            end
            internal.active = value
            if inRoot and value then
                value:activated()
                self:childactivated(value)
            end
        end
    },
    -- whether this object is active in one of it's ancestors
    isActive = {
        get = function(self)
            if self == module.root then return true end
            local e = self.parent
            while e do
                if e.activeChild == self then
                    return true
                end
                if e == module.root then break end
                e = e.parent
            end
            return false
        end
    },
    -- the (top-most) child of this object which is currently hovered by the mouse
    hoveredChild = {
        get = function(self)
            if not self.isHovered then return end
            local x, y = love.mouse.getPosition()
            for i, e in ipairs(self.children) do
                if e.isEnabled and e:check(x, y) then
                    return e
                end
            end
        end
    },
    -- whether this object is currently hovered by the mouse
    isHovered = {
        get = function(self)
            if self == module.root then
                return self:check(love.mouse.getPosition())
            end
            return self.parent and self.parent.isHovered and self.parent.hoveredChild == self or false
        end
    },
    -- a press register storing which object a press is currently interacting with
    pressedObject = {
        init = function(self)
            local internal = objects[self].internal
            internal.pressedObject = {}
            -- public proxy
            internal.pressedObjectProxy = setmetatable({}, {
                __index = internal.pressedObject, __newindex = function(t, k, v)
                    if not getPressPosition(k) then
                        error(("Invalid press ID: %s (%s)"):format(tostring(k), type(k)), 3)
                    end
                    if v ~= nil and not module.is(v) then
                        error(("Invalid object (got: %s (%s))"):format(tostring(v), type(v)), 3)
                    end
                    if v ~= nil and v.parent ~= self then
                        error(("Target must be a child of this object"), 2)
                    end
                    self:setPressTarget(k, v)
                end
            })
        end,
        get = function(self)
            local internal = objects[self].internal
            return internal.pressedObjectProxy
        end
    },
    -- the list of the IDs of all presses currently interacting with this object
    presses = {
        init = function(self)
            local internal = objects[self].internal
            internal.presses = inj.array.new()
        end,
        get = function(self)
            local internal = objects[self].internal
            local p = inj.array.new()
            for i, id in ipairs(internal.presses) do
                p:append(id)
            end
            return p
        end
    },
    -- the ID of the most recent press interacting with this object
    press = {
        get = function(self)
            local internal = objects[self].internal
            return internal.presses[-1]
        end
    },
    -- whether the object is currently pressed
    isPressed = {
        get = function(self)
            local internal = objects[self].internal
            return #internal.presses > 0
        end
    },
    -- a list of functions/tables to act as the index meta, in order
    indexes = {
        init = function(self)
            local internal = objects[self].internal
            internal.indexes = inj.array.new()
        end,
        get = function(self)
            local internal = objects[self].internal
            return internal.indexes
        end
    }
}

-- pre-defined checking functions for different common shapes
module.checks = {
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
    -- circle with center  origin
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
    -- union of all child module.checks
    children = function(self, x, y)
        for i, child in ipairs(self.children) do
            if child:check(x, y) then
                return true
            end
        end
        return false
    end
}
module.checks.default = module.checks.cornerRect

-- metatable
local objectMt = {
    __index = function(t, k)
        local ref = objects[t]
        return  k == "class" and ref.class or
                k == "check" and (ref.check or ref.class and ref.class.check or module.checks.default) or
                objectProperties[k] and objectProperties[k].get and objectProperties[k].get(t) or
                objectCallbacks[k] or
                objectFunctions[k] or
                _index(ref.internal.indexes, t, k) or
                ref.class and ref.class[k]
    end,
    __newindex = function(t, k, v)
        local ref = objects[t]
        if k == "class" then
            error("Cannot change an object's class after construction", 2)
        elseif k == "check" then
            if v == nil then
                ref.check = nil
            elseif type(v) == "boolean" then
                -- a shorthand for an infinite/non-existent hitbox
                ref.check = function() return v end
            elseif type(v) == "function" then
                ref.check = v
            else
                error(("Cannot assign non-function value to %q (got: %s (%s))"):format(k, tostring(v), type(v)), 2)
            end
        elseif objectFunctions[k] or inj.class[k] then
            error(("Cannot override the %q method"):format(tostring(k)), 2)
        elseif objectProperties[k] then
            if objectProperties[k].set then
                objectProperties[k].set(t, v)
            else
                error(("Cannot modify the %q field"):format(tostring(k)), 2)
            end
        elseif module.callbackNames[k] then
            if v == nil then
                ref.callbacks[k] = nil
            elseif type(v) == "boolean" then
                ref.callbacks[k] = function() return v end
            elseif type(v) == "function" then
                ref.callbacks[k] = v
            else
                error(("Cannot assign non-function value to %q (got: %s (%s))"):format(k, tostring(v), type(v)), 2)
            end
        else
            rawset(t, k, v)
        end
    end,
    __metatable = {},
    __tostring = function(t)
        local ref = objects[t]
        if not ref then return end
        return  type(t.tostring) == "function" and t:tostring() or
                type(t.tostring) == "string" and t.tostring or
                ("%s: %s"):format(t.class and t.class.name or "object", ref.name)
    end
}

-- object constructor
function module.new(object, class, ...)
    object = type(object) == "table" and object or {}
    if not pcall(setmetatable, object, nil) then
        error("Objects with custom metatables are not supported. If you want to implement an indexing metatable/metamethod, use the 'indexes' field", 2)
    end
    -- internal reference
    local ref = {
        name = tostring(object):match("table: (.+)") or tostring(object),
        class = class,
        callbacks = {},
        check = nil,
        internal = {}
    }
    objects[object] = ref
    -- copy all data out of the source table before transforming it
    local data = {}
    for k, v in pairs(object) do data[k], object[k] = v end
    setmetatable(object, objectMt)
    -- initialize properties
    for k, v in pairs(objectProperties) do
        if v.init then v.init(object) end
    end
    -- copy data back to source table
    for k, v in pairs(data) do
        if k ~= "parent" then
            local s, e = pcall(setk, object, k, v)
            if not s then error(e, 2) end
        end
    end
    -- initialize parent
    local s, e = pcall(setk, object, "parent", data.parent or module.root)
    if not s then error(e, 2) end
    -- call constructor
    if type(object.init) == "function" then
        object:init(...)
    end
    -- initialize screen dimensions
    object:resize(love.graphics.getDimensions())
    -- export object
    return object
end

return {
    module = module,
    inj = inj
}