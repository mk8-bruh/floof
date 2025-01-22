local _NAME = ...

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

local object = require(_NAME .. ".object")

local mouseButtons = {}

local lib = {
    checks = setmetatable({}, {
        __index = object.checks,
        __newindex = function(t, k, v)
            if type(v) ~= "function" then
                error(("Attempted to assign a non-function value to %q (got: %s (%s))"):format(tostring(k), tostring(v), type(v)), 2)
            end
            t[k] = v
        end
    }),
    is = object.is, isObject = object.is,
    new = object.new, newObject = object.new,
    root = object.root,
    init = function()
        local root = object.root
        if love then
            local old = {}
            for _, f in ipairs(loveCallbackNames) do
                old[f] = love[f] or emptyf
            end
            for _, f in ipairs(blockingCallbackNames) do
                love[f] = function(...)
                    return root[f](...) or old[f](...)
                end
            end
            for _, f in ipairs{"resize", "update", "draw", "quit"} do
                love[f] = function(...)
                    old[f](...)
                    root[f](...)
                end
            end
            love.mousepressed = function(...)
                local x, y, b, t = ...
                if b and not t then
                    mouseButtons[b] = true
                    return root.pressed(x, y, b) or old.mousepressed(...)
                end
            end
            love.mousemoved = function(...)
                local x, y, dx, dy, t = ...
                if not t then
                    local r = false
                    for b in pairs(mouseButtons) do
                        r = r or root.moved(x, y, dx, dy, b)
                    end
                    return r or old.mousemoved(...)
                end
            end
            love.mousereleased = function(...)
                local x, y, b, t = ...
                if b and not t then
                    mouseButtons[b] = nil
                    return root.released(x, y, b) or old.mousereleased(...)
                end
            end
            love.wheelmoved = function(...)
                local x, y = ...
                return root.scrolled(y) or old.wheelmoved(...)
            end
            love.touchpressed = function(...)
                local id, x, y = ...
                return root.pressed(x, y, id) or old.touchpressed(...)
            end
            love.touchmoved = function(...)
                local id, x, y, dx, dy = ...
                return root.moved(x, y, dx, dy, id) or old.touchmoved(...)
            end
            love.touchreleased = function(...)
                local id, x, y = ...
                return root.released(x, y, id) or old.touchreleased(...)
            end
            root.resize(love.graphics.getDimensions())
        end
    end
}

return setmetatable({}, {
	__index = lib,
	__newindex = emptyf,
	__metatable = {},
	__tostring = function() return 'hawk-tUI code on that thang :3' end
})