local emptyf, identityf = function(...) return end, function(...) return ... end

local callbackNames, activeCallbackNames = {
    "added", "removed", "addedto", "removedfrom",
    "activated", "deactivated", "childactivated", "childdeactivated",
    "enabled", "disabled",
    
    "resize", "update", "draw", "quit",

    "pressed", "moved", "released", "cancelled",
    "scrolled", "hovered", "unhovered",

    "keypressed", "keyreleased", "textinput",
    "filedropped", "directorydropped",
    "joystickadded", "joystickremoved",
    "joystickaxis", "joystickhat", "joystickpressed", "joystickreleased",
    "gamepadaxis", "gamepadpressed", "gamepadreleased"
}, {
    "keypressed", "keyreleased", "textinput",
    "filedropped", "directorydropped",
    "joystickadded", "joystickremoved",
    "joystickaxis", "joystickhat", "joystickpressed", "joystickreleased",
    "gamepadaxis", "gamepadpressed", "gamepadreleased"
}

local objectMt = {}
local function isObject(value) return getmetatable(value) == objectMt end

local root = {
    check = true
}

local objectCallbacks = {
    resize = function(self, internal, w, h)
        for i, e in ipairs(self.children) do
            e.resize(w, h)
        end
    end,
    update = function(self, internal, dt)
        for i, e in ipairs(self.children) do
            e.update(dt)
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
            if love and love.graphics then
                love.graphics.push("all")
            end
            e.draw()
            if love and love.graphics then
                love.graphics.pop()
            end
        end
    end,
    pressed = function(self, internal, x, y, id)
        local t = self.children
        for i, e in ipairs(t) do
            if e.check(x, y) and e.pressed(x, y, id) ~= false then
                self.setPressTarget(id, e)
                return true
            end
        end
    end,
    moved = function(self, internal, x, y, dx, dy, id)
        if self.pressedObject[id] then
            if self.pressedObject[id].moved(x, y, dx, dy, id) ~= true and not self.pressedObject[id].check(x, y) then
                self.pressedObject[id].cancelled(id)
                self.setPressTarget(id)
            end
            return true
        end
    end,
    released = function(self, internal, x, y, id)
        if self.pressedObject[id] then
            self.pressedObject[id].released(x, y, id)
            self.setPressTarget(id)
            return true
        end
    end,
    scrolled = function(self, internal, t)
        if self.hoveredChild then
            self.hoveredChild.scrolled(t)
            return true
        end
    end
}

for i, n in ipairs(activeCallbackNames) do
    objectCallbacks[n] = objectCallbacks[n] or function(self, internal, ...)
        if self.active then
            self.active[n](...)
            return true
        end
        return false
    end
end

for i, n in ipairs(callbackNames) do
    objectCallbacks[n] = objectCallbacks[n] or emptyf
end

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

local objectFunctions = {
    isChildOf = function(self, internal, object)
        if not isObject(object) then
            error(("Invalid object (got: %s (%s))"):format(tostring(object), type(object)), 3)
        end
        local e = self
        while e ~= root do
            e = e.parent
            if e == object then
                return true
            end
        end
        return false
    end,
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
        if object == root then return end
        if internal.pressedObject[id] == object then return end
        if internal.pressedObject[id] then
            for i, o in ipairs(internal.objectPresses[object]) do
                if o == id then
                    table.remove(internal.objectPresses[object], i)
                    break
                end
            end
            object.setPressTarget(id)
        end
        if object then
            table.insert(internal.objectPresses[object], id)
        end
        internal.pressedObject[id] = object
    end
}

local arrayMt = {
    __index = function(t, k)
        if type(k) == "number" then
            if k <= 0 then
                return rawget(t, #t + k + 1)
            end
        end
        return rawget(t, k)
    end,
    __newindex = function(t, k, v)
        if type(k) == "number" then
            if k <= 0 then
                return rawset(t, #t + k + 1, v)
            end
        end
        return rawset(t, k, v)
    end
}
local function newArray(t)
    return setmetatable(t or {}, arrayMt)
end

local objectProperties = {
    parent = {
        init = function(self, internal)
            if self ~= root then
                internal.parent = root
                internal.parent.childRegister[self] = true
            end
        end,
        get = function(self, internal)
            return internal.parent or root
        end,
        set = function(self, internal, value)
            if value == nil then value = root end
            if self.parent == value then return end
            if not isObject(value) then
                error(("Parent must be an object (got: %s (%s))"):format(tostring(value), type(value)), 3)
            end
            if value.isChildOf(self) then
                error(("Cannot assign object as the parent of its current parent"), 3)
            end
            local p = self.parent
            internal.parent = value
            p.childRegister[self] = nil
            p.removed(self)
            self.removedfrom(p)
            self.parent.childRegister[self] = true
            self.parent.added(self)
            self.addedto(self.parent)
        end
    },
    children = {
        get = function(self, internal)
            local children = newArray()
            for e in pairs(internal.childRegister) do
                table.insert(children, e)
            end
            table.sort(children, function(a, b) return (a.z or 0) > (b.z or 0) end)
            return children
        end,
        set = function(self, internal, value)
            if type(value) ~= "table" then
                error(("The value must be a table of objects (got:  %s (%s))"):format(tostring(value), type(value)), 3)
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
    childRegister = {
        init = function(self, internal)
            internal.childRegister = {}
            internal.childRegisterProxy = setmetatable({}, {
                __index = internal.childRegister, __newindex = function(t, k, v)
                    if isObject(k) then
                        if k.parent == self then
                            internal.childRegister[k] = true
                            internal.objectPresses[k] = internal.objectPresses[k] or newArray{_proxy = setmetatable({}, {
                                __index = function(o, i) if i ~= "_proxy" then return internal.objectPresses[k][i] end end, __newindex = emptyf
                            })}
                        else
                            internal.childRegister[k] = nil
                            for i, id in ipairs(internal.objectPresses[k]) do
                                internal.pressedObject[id] = nil
                            end
                            internal.objectPresses[k] = nil
                        end
                    end
                end
            })
        end,
        get = function(self, internal)
            return internal.childRegisterProxy
        end
    },
    isEnabled = {
        init = function(self, internal)
            internal.enabled = true
        end,
        get = function(self, internal)
            if self == root then return internal.enabled end
            return self.parent.isEnabled and internal.enabled
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
            end
        end
    },
    activeChild = {
        get = function(self, internal)
            if not internal.active.isChildOf(self) then internal.active = nil end
            return internal.active
        end,
        set = function(self, internal, value)
            if internal.active == value then return end
            if not isObject(value) and value ~= nil then
                error(("Active child must be an object (got: %s (%s))"):format(tostring(value), type(value)), 3)
            end
            if not value.isChildOf(self) then
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
    isActive = {
        get = function(self, internal)
            local e = self
            while e ~= root do
                e = e.parent
                if e.activeChild == self then
                    return true
                end
            end
            return false
        end
    },
    hoveredChild = {
        get = function(self, internal)
            if love and love.mouse then
                local x, y = love.mouse.getPosition()
                for i, e in ipairs(self.children) do
                    if e.check(x, y) then
                        return e
                    end
                end
            end
        end
    },
    isHovered = {
        get = function(self, internal)
            local e = self
            while e ~= root do
                e = e.parent
                if e.hoveredChild == self then
                    return true
                end
            end
            return false
        end
    },
    objectPresses = {
        init = function(self, internal)
            internal.objectPresses = {}
            if self == root then
                internal.objectPresses[self] = newArray()
            end
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
    objectPress = {
        init = function(self, internal)
            internal.objectPressProxy = setmetatable({}, {
                __index = function(t, k)
                    return self.objectPresses and self.objectPresses[k][-1] or nil
                end, __newindex = __emptyf
            })
        end,
        get = function(self, internal)
            return internal.objectPressProxy
        end
    },
    pressedObject = {
        init = function(self, internal)
            internal.pressedObject = {}
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
    presses = {
        get = function(self, internal)
            return self.parent.objectPresses[self]
        end
    },
    isPressed = {
        get = function(self, internal)
            return #self.presses > 0
        end
    },
    pressPositions = {
        init = function(self, internal)
            internal.pressPositionsProxy = setmetatable({}, {
                __index = function(t, k) return getPressPosition(self.presses[k]) end, __nexindex = emptyf
            })
        end,
        get = function(self, internal)
            return self.pressPositionsProxy
        end
    },
    pressPosition = {
        get = function(self, internal)
            return self.pressPositions[-1]
        end
    }
}

local checks = {
    cornerRect = function(self, x, y)
        if type(self.x) ~= "number" or type(self.y) ~= "number" or type(self.w) ~= "number" or type(self.h) ~= "number" then
            return false
        end
        return x >= self.x and x <= self.x + self.w and y >= self.y and y <= self.y + self.h
    end,
    centerRect = function(self, x, y)
        if type(self.x) ~= "number" or type(self.y) ~= "number" or type(self.w) ~= "number" or type(self.h) ~= "number" then
            return false
        end
        return x >= self.x - self.w/2 and x <= self.x + self.w/2 and y >= self.y - self.h/2 and y <= self.y + self.h/2
    end
}
checks.default = checks.cornerRect

local function newObject(object)
    object = type(object) == "table" and object or {}
    local name = tostring(object):match("table: (.+)") or tostring(object)
    local data = {}
    for k, v in pairs(object) do data[k], object[k] = v, nil end
    local internal = {}
    local callbacks, wrappers, methods = {}, {}, {}
    local check = nil
    for i, n in ipairs(callbackNames) do
        callbacks[n] = type(object[n]) == "function" and object[n] or emptyf
        wrappers[n] = function(...)
            return callbacks[n](object, ...) ~= false and objectCallbacks[n](object, internal, ...)
        end
    end
    for k, f in pairs(objectFunctions) do
        methods[k] = function(...)
            return f(object, internal, ...)
        end
    end
    setmetatable(object, {
        __index = function(t, k)
            if k == "check" then
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
                    if not s then
                        error(e, 2)
                    end
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
    for k, v in pairs(objectProperties) do
        if v.init then v.init(object, internal) end
    end
    for k, v in pairs(data) do object[k] = v end
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