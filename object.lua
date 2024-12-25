local emptyf, identityf = function(...) return end, function(...) return ... end

local callbackNames, activeCallbackNames, blockingCallbackNames = {
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
}, {
    "pressed", "moved", "released", "cancelled",
    "scrolled", "hovered", "unhovered",
    "activated", "deactivated", "enabled", "disabled",

    "keypressed", "keyreleased", "textinput",
    "filedropped", "directorydropped",
    "joystickadded", "joystickremoved",
    "joystickaxis", "joystickhat", "joystickpressed", "joystickreleased",
    "gamepadaxis", "gamepadpressed", "gamepadreleased"
}

local loveCallbackNames = {
    "resize", "update", "draw", "quit",

    "mousepressed", "mousemoved", "mousereleased", "wheelmoved",
    "touchpressed", "touchmoved", "touchreleased",

    "keypressed", "keyreleased", "textinput",
    "filedropped", "directorydropped",
    "joystickadded", "joystickremoved",
    "joystickaxis", "joystickhat", "joystickpressed", "joystickreleased",
    "gamepadaxis", "gamepadpressed", "gamepadreleased"
}

local objectMt = {}
local function isObject(value) return getmetatable(value) == objectMt end

local orphans = {}

local objectCallbacks = {

}

for i, n in ipairs(activeCallbackNames) do
    objectCallbacks[n] = objectCallbacks[n] or function(object, ...)
        if object.active then
            object.active[n](object.active, ...)
            return true
        end
    end
end

for i, n in ipairs(callbackNames) do
    objectCallbacks[n] = objectCallbacks[n] or emptyf
end

local objectFunctions = {
    isChildOf = function(self, object)
        local p = self.parent
        while p do
            if p == object then
                return true
            end
            p = p.parent
        end
        return false
    end
}

local objectProperties = {
    elements = {
        get = function(self, internal)
            local elements = {}
            for e in pairs(internal.register) do
                table.insert(elements, e)
            end
            table.sort(elements, function(a, b) return (a.z or 0) >= (b.z or 0) end)
            return elements
        end
    },
    register = {
        init = function(self, internal)
            internal.register = {}
        end,
        get = function(self, internal)
            if not internal.proxy then
                internal.proxy = setmetatable({}, {
                    __index = internal.register, __newindex = function(t, k, v)
                        if isObject(k) then
                            if k.parent == self then
                                internal.register[k] = true
                            else
                                internal.register[k] = false
                            end
                        end
                    end
                })
            end
            return internal.proxy
        end
    },
    active = {
        get = function(self, internal)
            return internal.active
        end,
        set = function(self, internal, value)
            if self.active == value then return end
            if not isObject(value) and value ~= nil then
                error(("Active element must be an object (got: %s (%s))"):format(tostring(value), type(value)), 2)
            end
            if value:isChildOf(self) then
                error(("Cannot assign %s, a parent of %s, as its active element"):format(tostring(value), tostring(self)))
            end
            if internal.active then
                internal.active:deactivated()
                self:deactivated(internal.active)
            end
            if value then
                value.parent = self
                internal.active = value
                value:activated()
                self:elementactivated(value)
            end
        end
    },
    hovered = {
        get = function(self, internal)
            if love and love.mouse then
                for i, e in ipairs(self.elements) do
                    if e:check(love.mouse.getPosition()) then
                        return e
                    end
                end
            end
        end
    },
    parent = {
        init = function(self, internal)
            orphans[self] = true
        end,
        get = function(self, internal)
            return internal.parent
        end,
        set = function(self, internal, value)
            if self.parent == value then return end
            if not isObject(value) and value ~= nil then
                error(("Cannot assign %s as the parent of %s"):format(tostring(value), tostring(self)), 2)
            end
            if value:isChildOf(self) then
                error(("Cannot assign %s as the parent of its parent %s"):format(tostring(value), tostring(self)))
            end
            local p = self.parent
            internal.parent = value
            if p then
                p.register[self] = nil
                p:removed(self)
                self:removedfrom(p)
            else
                orphans[self] = nil
            end
            if self.parent then
                self.parent.register[self] = true
                self.parent:added(self)
                self:addedto(self.parent)
            else
                orphans[self] = true
            end
        end
    },
    enabled = {
        init = function(self, internal)
            internal.enabled = true
        end,
        get = function(self, internal)
            return internal.enabled
        end,
        set = function(self, internal, value)
            if type(value) ~= "boolean" then
                error(("Enabled state must be a boolean value (got: %s (%s))"):format(tostring(value), type(value)))
            end
            if self.enabled == value then return end
            internal.enabled = value
            if value then
                self:enabled()
            else
                self:disabled()
            end
        end
    }
}

local defaultCheck = function(self, x, y)
    if type(self.x) ~= "number" or type(self.y) ~= "number" or type(self.w) ~= "number" or type(self.h) ~= "number" then
        return false
    end
    return x >= self.x and x <= self.x + self.w and y >= self.y and y <= self.y + self.h
end

local function newObject(object)
    object = type(object) == "table" and object or {}
    local data = {}
    for k, v in pairs(object) do data[k], object[k] = v, nil end
    local callbacks, wrappers = {}, {}
    local check = defaultCheck
    for i, n in ipairs(callbackNames) do
        callbacks[n] = type(object[n]) == "function" and object[n] or emptyf
        wrappers[n] = function(...)
            return callbacks[n](object, ...) ~= false and objectCallbacks[n](object, ...) ~= false
        end
    end
    local internal = {}
    setmetatable(object, {
        __index = function(t, k)
            return (k == "check" and check) or (objectProperties[k] and objectProperties[k].get and objectProperties[k].get(object, internal)) or wrappers[k] or objectFunctions[k]
        end,
        __newindex = function(t, k, v)
            if k == "check" then
                if type(v) == "bool" then
                    check = function() return v end
                elseif type(v) == "function" then
                    check = v
                else
                    error(("Cannot assign non-function value to %q"):format(k), 2)
                end
            elseif objectFunctions[k] then
                error(("Cannot override the %q method"):format(tostring(k)), 2)
            elseif objectProperties[k] then
                if objectProperties[k].set then
                    if not objectProperties[k].set(object, internal, v) then
                        error(("Cannot assign %s to the %q field"):format(tostring(v), tostring(k)), 2)
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
                    error(("Cannot assign non-function value to %q"):format(k), 2)
                end
            else
                rawset(t, k, v)
            end
        end,
        __metatable = objectMt,
        __tostring = function(t) return type(t.tostring) == "function" and t:tostring() or ("object<%s>"):format(tostring(t):match("%w+$")) end
    })
    for k, v in pairs(objectProperties) do
        if v.init then v.init(object, internal)
    end
    for k, v in pairs(data) do object[k] = v end
    return object
end

return {
    is = isObject,
    new = newObject,
    orphans = orphans
}