local _PATH = ...
local object = require(_PATH .. ".object")
local class  = require(_PATH .. ".class" )
local array  = require(_PATH .. ".array" )

object.inj.class,  object.inj.array = class.module,  array
class.inj.object,  class.inj.array  = object.module, array

local loveCallbackNames, blockingCallbackNames = {
    "resize", "update", "draw", "quit",

    "mousepressed", "mousemoved", "mousereleased", "wheelmoved",
    "touchpressed", "touchmoved", "touchreleased",

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

local emptyf, identityf = function(...) return end, function(...) return ... end

local lib = {
    checks = setmetatable({}, {
        __index = object.module.checks,
        __newindex = function(t, k, v)
            if v == nil then
                object.module.checks[k] = nil
            elseif type(v) == "boolean" then
                -- a shorthand for an infinite/non-existent hitbox
                object.module.checks[k] = function() return v end
            elseif type(v) == "function" then
                object.module.checks[k] = v
            else
                error(("Cannot add non-function value to checks (%q) (got: %s (%s))"):format(tostring(k), tostring(v), type(v)), 2)
            end
        end
    }),
    is = object.module.is, isObject = object.module.is,
    new = object.module.new, newObject = object.module.new,
    setRoot = object.module.setRoot,
    class = class.module,
    init = function()
        if not love then return end
        local old = {}
        for _, f in ipairs(loveCallbackNames) do
            old[f] = love[f] or emptyf
        end
        for _, f in ipairs(blockingCallbackNames) do
            love[f] = function(...)
                return object.module.root and object.module.root[f](object.module.root, ...) or old[f](...)
            end
        end
        for _, f in ipairs{"resize", "update", "draw", "quit"} do
            love[f] = function(...)
                old[f](...)
                if object.module.root then
                    object.module.root[f](object.module.root, ...)
                end
            end
        end
        love.mousepressed = function(...)
            local x, y, b, t = ...
            if b and not t and object.module.root then
                object.module.root:keypressed(("mouse%d"):format(b))
            end
            if b and not t and object.module.root and object.module.root:check(x, y) and object.module.root:pressed(x, y, b) ~= false then
                return
            end
            old.mousepressed(...)
        end
        love.mousemoved = function(...)
            local x, y, dx, dy, t = ...
            if love.mouse.getRelativeMode() and object.module.root then
                object.module.root:mousedelta(dx, dy)
                return
            end
            if not t and object.module.root then
                local r = false
                for i, b in ipairs(object.module.root.presses) do
                    if type(b) == "number" then
                        if object.module.root:moved(x, y, dx, dy, b) then
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
            if b and not t and object.module.root then
                object.module.root:keyreleased(("mouse%d"):format(b))
            end
            if b and not t and object.module.root and object.module.root.presses:find(b) then
                object.module.root:released(x, y, b)
                return
            end
            old.mousereleased(...)
        end
        love.wheelmoved = function(...)
            local x, y = ...
            return object.module.root and object.module.root.isHovered and object.module.root:scrolled(y) or old.wheelmoved(...)
        end
        love.touchpressed = function(...)
            local id, x, y = ...
            if object.module.root and object.module.root:check(x, y) and object.module.root:pressed(x, y, id) ~= false then
                return
            end
            old.touchpressed(...)
        end
        love.touchmoved = function(...)
            local id, x, y, dx, dy = ...
            if object.module.root and object.module.root.presses:find(id) and object.module.root:moved(x, y, dx, dy, id) then
                return
            end
            old.touchmoved(...)
        end
        love.touchreleased = function(...)
            local id, x, y = ...
            if object.module.root and object.module.root.presses:find(id) then
                object.module.root:released(x, y, id)
                return
            end
            old.touchreleased(...)
        end
    end
}

object.module.setRoot(object.module.new{check = true})

return setmetatable({}, {
	__index = function(t, k)
        if k == "root" then
            return object.module.root
        end
        return lib[k]
    end,
	__newindex = function(t, k, v)
        if k == "root" then
            if v ~= nil and not object.module.is(v) then
                error(("Invalid object (got: %s (%s))"):format(tostring(v), type(v)), 2)
            end
            object.module.setRoot(v)
        end
    end,
	__metatable = {},
	__tostring = function() return 'FLOOF' end,
    __call = function(_, ...)
        local s, v = pcall(lib.new, ...)
        if not s then
            error(v, 2)
        else
            return v
        end
    end
})