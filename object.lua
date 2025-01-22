local emptyf, identityf = function(...) return end, function(...) return ... end

local callbackNames, activeCallbackNames = {
    "added", "removed", "addedto", "removedfrom",
    "activated", "deactivated", "elementactivated", "elementdeactivated",
    "enabled", "disabled", "elementenabled", "elementdisabled",
    
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

local root

local objectCallbacks = {
    resize = function(self, internal, w, h)
        for i, e in ipairs(self.elements) do
            e.resize(w, h)
        end
    end,
    update = function(self, internal, dt)
        for i, e in ipairs(self.elements) do
            e.update(dt)
        end
        if internal.lastHovered ~= self.hoveredElement then
            if internal.lastHovered then
                internal.lastHovered.unhovered()
            end
            if self.hoveredElement then
                self.hoveredElement.hovered()
            end
            internal.lastHovered = self.hoveredElement
        end
    end,
    quit = function(self, internal)
        for i, e in ipairs(self.elements) do
            e.quit()
        end
    end,
    draw = function(self, internal)
        local t = self.elements
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
        local t = self.elements
        for i, e in ipairs(t) do
            if e.pressed(x, y, id) ~= false then
                self.addPress(e, id)
                return true
            end
        end
    end,
    moved = function(self, internal, x, y, dx, dy, id)
        if self.pressedObject[id] then
            if self.pressedObject[id].moved(x, y, dx, dy, id) ~= true and not self.pressedObject[id].check(x, y) then
                self.pressedObject[id].cancelled(id)
                self.removePress(id)
            end
            return true
        end
    end,
    released = function(self, internal, x, y, id)
        if self.pressedObject[id] then
            self.pressedObject[id].released(x, y, id)
            self.removePress(id)
            return true
        end 
    end,
    scrolled = function(self, internal, t)
        if self.hoveredElement then
            self.hoveredElement.scrolled(t)
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
    end
end

for i, n in ipairs(callbackNames) do
    objectCallbacks[n] = objectCallbacks[n] or emptyf
end

local objectFunctions = {
    isChildOf = function(self, internal, object)
        if not isObject(object) then
            error(("Invalid object (got: %s (%s))"):format(tostring(object), type(object)), 3)
        end
        if self == root then return object == root end
        return self.parent == object or self.parent.isChildOf(object)
    end,
    addPress = function(self, internal, object, id)
        if not isObject(object) then
            error(("Invalid object (got: %s (%s))"):format(tostring(object), type(object)), 3)
        end
        if object.parent ~= self then
            error(("Object must be a child of this element"), 3)
        end
        if not getPressPosition(id) then
            error(("Invalid press ID: %s (%s)"):format(tostring(id), type(id)), 3)
        end
        if object == root then return end
        if internal.pressedObject[id] == object then return end
        if internal.pressedObject[id] then
            internal.pressedObject[id].cancelled(id)
            self.removePress(id)
        end
        table.insert(internal.objectPresses[object], id)
        internal.pressedObject[id] = object
    end,
    removePress = function(self, internal, id)
        if not isObject(object) then
            error(("Invalid object (got: %s (%s))"):format(tostring(object), type(object)), 3)
        end
        if object.parent ~= self then
            error(("Object must be a child of this element"), 3)
        end
        if not getPressPosition(id) then
            error(("Invalid press ID: %s (%s)"):format(tostring(id), type(id)), 3)
        end
        if not internal.pressedObject[id] then return end
        local object = internal.pressedObject[id]
        for i, o in ipairs(internal.objectPresses[object]) do
            if o == id then
                table.remove(internal.objectPresses[object], i)
                break
            end
        end
        internal.pressedObject[id] = nil
    end
}

local function getPressPosition(id)
    if type(id) == "number" then
        if love and love.mouse then
            return love.mouse.getPosition()
        end
    else
        if love and love.touch then
            local s, ... = pcall(love.touch.getPosition, id)
            if s then
                return ...
            end
        end
    end
end

local arrayMt = {
    __index = function(t, k)
        if type(k) == "number" then
            if k <= 0 then
                return t[#t + k + 1]
            end
        end
        return t[k]
    end,
    __newindex = function(t, k, v)
        if type(k) == "number" then
            if k <= 0 then
                t[#t + k + 1] = v return
            end
        end
        t[k] = v return
    end
}
local function newArray(t)
    return setmetatable(t or {}, arrayMt)
end

local objectProperties = {
    elements = {
        get = function(self, internal)
            local elements = {}
            for e in pairs(internal.elementRegister) do
                table.insert(elements, e)
            end
            table.sort(elements, function(a, b) return (a.z or 0) >= (b.z or 0) end)
            return elements
        end
    },
    elementRegister = {
        init = function(self, internal)
            internal.elementRegister = {}
            internal.elementRegisterProxy = setmetatable({}, {
                __index = internal.elementRegister, __newindex = function(t, k, v)
                    if isObject(k) then
                        if k.parent == self then
                            internal.elementRegister[k] = true
                            internal.objectPresses[k] = internal.objectPresses[k] or newArray{_proxy = setmetatable({}, {
                                __index = function(o, i) if i ~= "_proxy" then return internal.objectPresses[k][i] end end, __newindex = emptyf
                            })}
                        else
                            internal.elementRegister[k] = nil
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
            return internal.elementRegisterProxy
        end
    },
    activeElement = {
        get = function(self, internal)
            return internal.active
        end,
        set = function(self, internal, value)
            if internal.active == value then return end
            if not isObject(value) and value ~= nil then
                error(("Active element must be an object (got: %s (%s))"):format(tostring(value), type(value)), 3)
            end
            if not value.isChildOf(self) then
                error(("Active element must be a child of the object"), 3)
            end
            if value == root then
                error(("Cannot set root as the active element"), 3)
            end
            if internal.active then
                internal.active.deactivated()
                self.elementdeactivated(internal.active)
            end
            if value then
                value.parent = self
                internal.active = value
                value.activated()
                self.elementactivated(value)
            end
        end
    },
    active = {
        get = function(self, internal)
            local e = self
            while e ~= root do
                e = e.parent
                if e.activeElement == self then
                    return true
                end
            end
            return false
        end
    },
    hoveredElement = {
        get = function(self, internal)
            if love and love.mouse then
                local x, y = love.mouse.getPosition()
                for i, e in ipairs(self.elements) do
                    if e.check(x, y) then
                        return e
                    end
                end
            end
        end
    },
    hovered = {
        get = function(self, internal)
            local e = self
            while e ~= root do
                e = e.parent
                if e.hoveredElement == self then
                    return true
                end
            end
            return false
        end
    },
    parent = {
        init = function(self, internal)
            if self == root then
                internal.parent = self
                internal.elementRegister[self] = true
            else
                internal.parent = root
                internal.parent.elementRegister[self] = true
            end
        end,
        get = function(self, internal)
            return internal.parent
        end,
        set = function(self, internal, value)
            if value == nil then value = root end
            if self.parent == value then return end
            if not isObject(value) and value ~= nil then
                error(("Parent must be an object (got: %s (%s))"):format(tostring(value), type(value)), 3)
            end
            if value.isChildOf(self) then
                error(("Cannot assign object as the parent of its parent"), 3)
            end
            local p = self.parent
            internal.parent = value
            p.elementRegister[self] = nil
            p.removed(self)
            self.removedfrom(p)
            self.parent.elementRegister[self] = true
            self.parent.added(self)
            self.addedto(self.parent)
        end
    },
    enabled = {
        init = function(self, internal)
            internal.enabled = true
        end,
        get = function(self, internal)
            if self == root then return internal.enabled end
            return self.parent.enabled and internal.enabled
        end,
        set = function(self, internal, value)
            if type(value) ~= "boolean" then
                error(("Enabled state must be a boolean value (got: %s (%s))"):format(tostring(value), type(value)), 3)
            end
            if self.enabled == value then return end
            internal.enabled = value
            if value then
                self.enabled()
            else
                self.disabled()
            end
        end
    },
    objectPresses = {
        init = function(self, internal)
            internal.objectPresses = {}
            if self == root then
                internal.objectPresses[self] = newArray{_proxy = setmetatable({}, {
                    __index = function(o, i) if i ~= "_proxy" then return internal.objectPresses[self][i] end end, __newindex = emptyf
                })}
            end
            internal.objectPressesProxy = setmetatable({}, {
                __index = function(t, k)
                    return internal.objectPresses[k] and internal.objectPresses[k].proxy
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
                        error(("Invalid press ID: %s (%s)"):format(tostring(k), type(k)), 2)
                    end
                    if not isObject(v) and v ~= nil then
                        error(("Press target must be an object or nil (got: %s (%s))"):format(tostring(v), type(v)), 2)
                    end
                    if v == root then return end
                    local o = internal.pressedObject[k]
                    internal.pressedObject[k] = v
                    if o then
                        self.removePress(k)
                    end
                    if v then
                        local x, y = getPressPosition(k)
                        v.pressed(x, y, k)
                    end
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
    pressed = {
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
    local data = {}
    for k, v in pairs(object) do data[k], object[k] = v, nil end
    local internal = {}
    local callbacks, wrappers, methods = {}, {}, {}
    local check = nil
    for i, n in ipairs(callbackNames) do
        callbacks[n] = type(object[n]) == "function" and object[n] or emptyf
        wrappers[n] = function(...)
            return callbacks[n](object, ...) ~= false and objectCallbacks[n](object, internal, ...) == true or nil
        end
    end
    for k, f in pairs(objectFunctions) do
        methods[k] = function(...)
            f(object, internal, ...)
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
                elseif type(v) == "bool" then
                    check = function() return v end
                elseif type(v) == "function" then
                    check = v
                else
                    error(("Cannot assign non-function value to %q (got: %s (%s))"):format(k, tostring(v), type(v)), 2)
                end
            elseif methods[k] then
                error(("Cannot override the %q method"):format(tostring(k)), 2)
            elseif objectProperties[k] then
                if objectProperties[k].set then
                    local s, e = pcall(objectProperties[k].set, object, internal, v)
                    if not s then
                        error(e, 2)
                    end
                else
                    error(("Cannot modify the %q field"):format(tostring(k)), 2)
                end
            elseif callbacks[k] then
                if v == nil then
                    callbacks[k] = emptyf
                elseif type(v) == "function" then
                    callbacks[k] = v
                else
                    error(("Cannot assign non-function value to %q (got: %s (%s))"):format(k, tostring(v), type(v)), 2)
                end
            else
                rawset(t, k, v)
            end
        end,
        __metatable = objectMt,
        __tostring = function(t) return type(t.tostring) == "function" and t:tostring() or ("object<%s>"):format(tostring(t):match("table: (.+)")) end
    })
    for k, v in pairs(objectProperties) do
        if v.init then v.init(object, internal)
    end
    for k, v in pairs(data) do object[k] = v end
    return object
end

root = newObject{
    check = true
}

return {
    is = isObject,
    new = newObject,
    root = root,
    checks = checks
}