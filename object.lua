-- dummy functions
local emptyf, identityf = function(...) return end, function(...) return ... end
local setk = function(t, k, v) t[k] = v end

-- Python-like array class
local arrayMt
local function isArray(t)
    return getmetatable(t) == arrayMt
end
local function newArray(...)
    local array = setmetatable({}, arrayMt)
    for i, v in ipairs{...} do
        table.insert(array, v)
    end
    return array
end
-- number string truncation (get rid of excessive decimals)
local ntostr = function(n) return tostring(n):match("^(.-)%.?0*$") end
arrayMt = {
    __index = function(t, k)
        if type(k) == "number" and k == math.floor(k) then
            if k <= 0 then
                k = #t + k + 1
            end
            return rawget(t, i)
        end
    end,
    __newindex = function(t, k, v)
        if type(k) == "number" and k == math.floor(k) then
            if k <= 0 then
                k = #t + k + 1
            end
            if k <= 0 or k > #t + 1 then return end
            rawset(t, k, v)
        end
    end,
    __tostring = function(t)
        if #t == 0 then return "[]" end
        local s = ntostr(t[1]) or tostring(t[1])
        for i = 2, #t do
            s = s .. (", %s"):format(ntostr(t[i]) or tostring(t[i]))
        end
        return ("[%s]"):format(s)
    end,
    __concat = function(a, b)
        local array = setmetatable({}, arrayMt)
        for i, v in ipairs(a) do
            table.insert(array, v)
        end
        for i, v in ipairs(b) do
            table.insert(array, v)
        end
        return array
    end
}

-- generalized position grabber (touch/mouse)
local function getPressPosition(id)
    if type(id) == "number" then
        if love and love.mouse then
            return love.mouse.getPosition()
        end
    else
        if love and love.touch then
            local s, x, y = pcall(love.touch.getPosition, id)
            if s then
                return x, y
            end
        end
    end
end

-- callback list
local callbackNames, activeCallbackNames = {
    "resize", "update", "draw", "quit",

    "pressed", "moved", "released", "cancelled",
    "scrolled", "hovered", "unhovered",

    "keypressed", "keyreleased", "textinput",
    "filedropped", "directorydropped",
    "joystickadded", "joystickremoved",
    "joystickaxis", "joystickhat", "joystickpressed", "joystickreleased",
    "gamepadaxis", "gamepadpressed", "gamepadreleased",

    "created", "deleted", "added", "removed", "addedto", "removedfrom",
    "activated", "deactivated", "childactivated", "childdeactivated",
    "enabled", "disabled",
}, {
    "keypressed", "keyreleased", "textinput",
    "filedropped", "directorydropped",
    "joystickadded", "joystickremoved",
    "joystickaxis", "joystickhat", "joystickpressed", "joystickreleased",
    "gamepadaxis", "gamepadpressed", "gamepadreleased"
}

-- object identification
local objectMt = {}
local function isObject(value) return getmetatable(value) == objectMt end

-- root object
local root = {
    check = true
}

-- unique object callbacks
local objectCallbacks = {
    resize = function(self, internal, w, h)
        for i, e in ipairs(self.children) do
            e.resize(w, h)
        end
    end,
    update = function(self, internal, dt)
        for i, e in ipairs(self.children) do
            if e.isEnabled then
                e.update(dt)
            end
        end
        if internal.lastHovered ~= self.hoveredChild then
            if internal.lastHovered then
                internal.lastHovered.unhovered()
            end
            if self.hoveredChild then
                self.hoveredChild.hovered()
            end
            internal.lastHovered = self.hoveredChild
        end
    end,
    quit = function(self, internal)
        for i, e in ipairs(self.children) do
            e.quit()
        end
    end,
    draw = function(self, internal)
        local t = self.children
        for i = #t, 1, -1 do
            local e = t[i]
            if e.isEnabled then
                if love and love.graphics then
                    love.graphics.push("all")
                end
                e.draw()
                if love and love.graphics then
                    love.graphics.pop()
                end
            end
        end
    end,
    pressed = function(self, internal, x, y, id)
        local t = self.children
        if self == root then
            -- track all presses in root
            table.insert(internal.objectPresses[self], id)
        end
        for i, e in ipairs(t) do
            if e.isEnabled and e.check(x, y) and e.pressed(x, y, id) ~= false then
                self.setPressTarget(id, e)
                return true
            end
        end
    end,
    moved = function(self, internal, x, y, dx, dy, id)
        if self.pressedObject[id] then
            if self.pressedObject[id].moved(x, y, dx, dy, id) ~= true and not self.pressedObject[id].check(x, y) then
                -- object should no longer be pressed
                self.pressedObject[id].cancelled(id)
                self.setPressTarget(id)
            end
            return true
        end
    end,
    released = function(self, internal, x, y, id)
        if self == root then
            -- find and remove press from root
            for i, o in ipairs(internal.objectPresses[self]) do
                if o == id then
                    table.remove(internal.objectPresses[self], i)
                    break
                end
            end
        end
        if self.pressedObject[id] then
            self.pressedObject[id].released(x, y, id)
            self.setPressTarget(id)
            return true
        end
    end,
    cancelled = function(self, internal, id)
        if self == root then
            -- same here
            for i, o in ipairs(internal.objectPresses[self]) do
                if o == id then
                    table.remove(internal.objectPresses[self], i)
                    break
                end
            end
        end
        if self.pressedObject[id] then
            self.pressedObject[id].cancelled(id)
            self.setPressTarget(id)
        end
    end,
    scrolled = function(self, internal, t)
        if self.hoveredChild then
            self.hoveredChild.scrolled(t)
            return true
        end
    end
}

-- default callbacks called on the active element
for i, n in ipairs(activeCallbackNames) do
    objectCallbacks[n] = objectCallbacks[n] or function(self, internal, ...)
        if internal.active and internal.active.isEnabled then
            internal.active[n](...)
            return true
        end
        return false
    end
end

-- remaining empty callbacks
for i, n in ipairs(callbackNames) do
    objectCallbacks[n] = objectCallbacks[n] or emptyf
end

-- methods for object interaction (can access the internal state)
local objectFunctions = {
    -- update the status of the object in this object's register (used internally)
    updateChildStatus = function(self, internal, object)
        if not isObject(object) then
            error(("Invalid object (got: %s (%s))"):format(tostring(object), type(object)), 3)
        end
        if object.parent == self then
            internal.childRegister[object] = true
            internal.objectPresses[object] = internal.objectPresses[k] or newArray()
        else
            internal.childRegister[object] = nil
            for i, id in ipairs(internal.objectPresses[object]) do
                internal.pressedObject[id] = nil
            end
            internal.objectPresses[object] = nil
        end
        self.refreshChildren()
    end,
    -- recalculate the child order according to z-indexes (used internally)
    refreshChildren = function(self, internal)
        internal.children = {}
        for c in pairs(internal.childRegister) do
            table.insert(internal.children, c)
        end
        table.sort(internal.children, function(a, b) return a.z > b.z end)
    end,
    -- traverse the hierarchy upwards and check for object
    isChildOf = function(self, internal, object)
        if not isObject(object) then
            error(("Invalid object (got: %s (%s))"):format(tostring(object), type(object)), 3)
        end
        local e = self
        while e ~= root do
            e = e.parent
            if not e then break end
            if e == object then
                return true
            end
        end
        return false
    end,
    -- change which element is interacting with a press
    setPressTarget = function(self, internal, id, object)
        if not getPressPosition(id) then
            error(("Invalid press ID: %s (%s)"):format(tostring(id), type(id)), 3)
        end
        if object ~= null and not isObject(object) then
            error(("Invalid object (got: %s (%s))"):format(tostring(object), type(object)), 3)
        end
        if object ~= null and object.parent ~= self then
            error(("Target must be a child of this object"), 3)
        end
        if internal.pressedObject[id] == object then return end
        if internal.pressedObject[id] then
            local p = internal.pressedObject[id]
            for i, o in ipairs(internal.objectPresses[p]) do
                if o == id then
                    table.remove(internal.objectPresses[p], i)
                    break
                end
            end
            p.setPressTarget(id)
        end
        if object then
            table.insert(internal.objectPresses[object], id)
        end
        internal.pressedObject[id] = object
    end,
    -- get the position of the i-th press on this element, or the most recent press if unspecified
    getPressPosition = function(self, internal, i)
        if i == nil then
            i = -1
        end
        if not self.presses[i] then
            error(("Invalid index (got: %s (%s))"):format(tostring(i), type(i)), 3)
        end
        return getPressPosition(self.presses[i])
    end
}

-- protected properties of objects; each has an initializer, getter and setter (except for those that don't)
local objectProperties = {
    -- the object which this object is a child of
    parent = {
        get = function(self, internal)
            if self == root then
                -- root is its own parent
                return self
            end
            return internal.parent
        end,
        set = function(self, internal, value)
            if self.parent == value then return end
            if value ~= nil and not isObject(value) then
                error(("Parent must be an object (got: %s (%s))"):format(tostring(value), type(value)), 3)
            end
            if self == value then
                error(("Cannot assign object as its own parent"), 3)
            end
            if value and value.isChildOf(self) then
                error(("Cannot assign object as the parent of its current parent"), 3)
            end
            -- deactivate in all parent objects
            local e = self
            while e ~= root do
                e = e.parent
                if not e or value.isChildOf(e) then break end
                if e.activeChild == self then
                    e.activeChild = nil
                end
            end
            local p = self.parent
            internal.parent = value
            if p then
                p.updateChildStatus(self)
                p.removed(self)
                self.removedfrom(p)
            else
                self.created()
            end
            if value then
                self.parent.updateChildStatus(self)
                self.parent.added(self)
                self.addedto(self.parent)
            else
                self.deleted()
            end
        end
    },
    -- a register of all the children of this object (used internally)
    childRegister = {
        init = function(self, internal)
            internal.childRegister = {}
        end
    },
    -- a list of this component's children sorted from front to back
    children = {
        init = function(self, internal)
            internal.children = newArray()
        end,
        get = function(self, internal)
            local children = newArray()
            for i, e in ipairs(internal.children) do
                table.insert(children, e)
            end
            return children
        end,
        set = function(self, internal, value)
            -- shorthand for setting this object as parent to each of the objects
            if type(value) ~= "table" then
                error(("Value must be a table of objects (got:  %s (%s))"):format(tostring(value), type(value)), 3)
            end
            for i, v in ipairs(value) do
                if not isObject(v) then
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
        init = function(self, internal)
            internal.z = 0
        end,
        get = function(self, internal)
            return internal.z
        end,
        set = function(self, internal, value)
            if type(value) ~= "number" then
                error(("Z value must be a number (got: %s (%s))"):format(tostring(value), type(value)), 3)
            end
            internal.z = value
            if self.parent then self.parent.refreshChildren() end
        end
    },
    -- whether the object is currently enabled for receiving callbacks
    enabledSelf = {
        init = function(self, internal)
            internal.enabled = true
        end,
        get = function(self, internal)
            return internal.enabled
        end,
        set = function(self, internal, value)
            if type(value) ~= "boolean" then
                error(("Enabled state must be a boolean value (got: %s (%s))"):format(tostring(value), type(value)), 3)
            end
            if internal.enabled == value then return end
            internal.enabled = value
            if value then
                self.enabled()
            else
                self.disabled()
                for i, p in ipairs(self.presses) do
                    self.cancelled(p)
                    self.parent.setPressTarget(p)
                end
            end
        end
    },
    -- the global enabled state of the object
    isEnabled = {
        get = function(self, internal)
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
        get = function(self, internal)
            return internal.active
        end,
        set = function(self, internal, value)
            if internal.active == value then return end
            if not isObject(value) and value ~= nil then
                error(("Active child must be an object (got: %s (%s))"):format(tostring(value), type(value)), 3)
            end
            if value ~= nil and not value.isChildOf(self) then
                error(("Active child must be a child of the object"), 3)
            end
            if value == root then
                error(("Cannot set root as the active child"), 3)
            end
            if self.activeChild then
                internal.active.deactivated()
                self.childdeactivated(internal.active)
            end
            internal.active = value
            if value then
                value.parent = self
                value.activated()
                self.childactivated(value)
            end
        end
    },
    -- whether this object is active in one of it's ancestors
    isActive = {
        get = function(self, internal)
            local e = self
            while e ~= root do
                e = e.parent
                if not e then break end
                if e.activeChild == self then
                    return true
                end
            end
            return false
        end
    },
    -- the (top-most) child of this object which is currently hovered by the mouse
    hoveredChild = {
        get = function(self, internal)
            if love and love.mouse then
                local x, y = love.mouse.getPosition()
                for i, e in ipairs(self.children) do
                    if e.isEnabled and e.check(x, y) then
                        return e
                    end
                end
            end
        end
    },
    -- whether this object is currently hovered by the mouse
    isHovered = {
        get = function(self, internal)
            return self.parent.hoveredChild == self
        end
    },
    -- the lists of the IDs of all presses currently interacting with this object's children, which are the keys of the table
    objectPresses = {
        init = function(self, internal)
            internal.objectPresses = {}
            if self == root then
                -- root press register
                internal.objectPresses[self] = newArray()
            end
            -- proxy table for public access
            internal.objectPressesProxy = setmetatable({}, {
                __index = function(t, k)
                    if internal.objectPresses[k] then
                        local t = newArray()
                        for i, id in ipairs(internal.objectPresses[k]) do
                            table.insert(t, id)
                        end
                        return t
                    end
                end, __newindex = emptyf
            })
        end,
        get = function(self, internal)
            return internal.objectPressesProxy
        end
    },
    -- the IDs of the most recent presses on this object's children (again, entry per child)
    objectPress = {
        init = function(self, internal)
            internal.objectPressProxy = setmetatable({}, {
                __index = function(t, k)
                    return self.objectPresses[k] and self.objectPresses[k][-1] or nil
                end, __newindex = __emptyf
            })
        end,
        get = function(self, internal)
            return internal.objectPressProxy
        end
    },
    -- a press register storing which object a press is currently interacting with
    pressedObject = {
        init = function(self, internal)
            internal.pressedObject = {}
            -- public proxy
            internal.pressedObjectProxy = setmetatable({}, {
                __index = internal.pressedObject, __newindex = function(t, k, v)
                    if not getPressPosition(k) then
                        error(("Invalid press ID: %s (%s)"):format(tostring(k), type(k)), 3)
                    end
                    if v ~= null and not isObject(v) then
                        error(("Invalid object (got: %s (%s))"):format(tostring(v), type(v)), 3)
                    end
                    if v ~= nil and v.parent ~= self then
                        error(("Target must be a child of this object"), 3)
                    end
                    self.setPressTarget(k, v)
                end
            })
        end,
        get = function(self, internal)
            return internal.pressedObjectProxy
        end
    },
    -- the list of the IDs of all presses currently interacting with this object
    presses = {
        get = function(self, internal)
            return self.parent.objectPresses[self]
        end
    },
    -- the ID of the most recent press interacting with this object
    isPressed = {
        get = function(self, internal)
            return #self.presses > 0
        end
    }
}

-- pre-defined checking functions for different common shapes
local checks = {
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
    end
}
checks.default = checks.cornerRect

-- object constructor
local function newObject(object)
    object = type(object) == "table" and object or {}
    if not pcall(setmetatable, object, nil) then
        error("Object with custom metatables are not supported", 2)
    end
    local name = tostring(object):match("table: (.+)") or tostring(object)
    local data = {}
    -- copy all data out of the source table before transforming it
    for k, v in pairs(object) do data[k], object[k] = v, nil end
    -- private variables
    local internal = {}
    -- overlay callback functions, callback wrappers that package the overlay and the internal callback, and method wrappers that expose the internal table
    local callbacks, wrappers, methods = {}, {}, {}
    -- the current checking function of the object
    local check = nil
    -- construct callback wrappers
    for i, n in ipairs(callbackNames) do
        callbacks[n] = emptyf
        wrappers[n] = n == "draw" and function(...)
            -- custom 'draw' callback that restores the state for neater graphics code
            if love and love.graphics then
                love.graphics.push("all") love.graphics.push("all")
            end
            if callbacks[n](object, ...) == false then return false end
            if love and love.graphics then love.graphics.pop() end
            objectCallbacks[n](object, internal, ...)
            if love and love.graphics then love.graphics.pop() end
        end or function(...)
            return callbacks[n](object, ...) ~= false and objectCallbacks[n](object, internal, ...)
        end
    end
    -- method wrappers
    for k, f in pairs(objectFunctions) do
        methods[k] = function(...)
            return f(object, internal, ...)
        end
    end
    -- custom metatable
    setmetatable(object, {
        __index = function(t, k)
            if k == "check" then
                -- default check reflects changes for objects even after construction
                return function(...) return (check or checks.default)(object, ...) end
            elseif objectProperties[k] then
                return objectProperties[k].get and objectProperties[k].get(object, internal)
            elseif wrappers[k] then
                return wrappers[k]
            elseif methods[k] then
                return methods[k]
            end
        end,
        __newindex = function(t, k, v)
            if k == "check" then
                if v == nil then
                    check = nil
                elseif type(v) == "boolean" then
                    -- a shorthand for an infinite/non-existent hitbox
                    check = function() return v end
                elseif type(v) == "function" then
                    check = v
                else
                    error(("Cannot assign non-function value to %q (got: %s (%s))"):format(k, tostring(v), type(v)), 3)
                end
            elseif methods[k] then
                error(("Cannot override the %q method"):format(tostring(k)), 3)
            elseif objectProperties[k] then
                if objectProperties[k].set then
                    local s, e = pcall(objectProperties[k].set, object, internal, v)
                    if not s then error(e, 2) end
                else
                    error(("Cannot modify the %q field"):format(tostring(k)), 3)
                end
            elseif callbacks[k] then
                if v == nil then
                    callbacks[k] = emptyf
                elseif type(v) == "boolean" then
                    callbacks[k] = function() return v end
                elseif type(v) == "function" then
                    callbacks[k] = v
                else
                    error(("Cannot assign non-function value to %q (got: %s (%s))"):format(k, tostring(v), type(v)), 3)
                end
            else
                rawset(t, k, v)
            end
        end,
        __metatable = objectMt,
        __tostring = function(t) return type(t.tostring) == "function" and t:tostring() or ("object<%s>"):format(name) end
    })
    -- initialize properties
    for k, v in pairs(objectProperties) do
        if v.init then v.init(object, internal) end
    end
    -- copy data back to source table
    for k, v in pairs(data) do
        if k ~= "parent" then
            local s, e = pcall(setk, object, k, v)
            if not s then error(e, 2) end
        end
    end
    -- initialize parent
    local s, e = pcall(setk, object, "parent", data.parent or root)
    if not s then error(e, 2) end
    -- initialize screen dimensions
    if love and love.graphics then
        object.resize(love.graphics.getDimensions())
    end
    
    return object
end

root = newObject(root)

return {
    is = isObject,
    new = newObject,
    root = root,
    checks = checks
}