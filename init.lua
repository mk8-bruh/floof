local _PATH = ...
local object = require(_PATH .. ".object")
local class  = require(_PATH .. ".class" )
local array  = require(_PATH .. ".array" )

object.inj.class,  object.inj.array = class.module,  array
class.inj.object,  class.inj.array  = object.module, array

local root = object.module.new{check = true}
object.inj.root = root

local emptyf, identityf = function(...) return end, function(...) return ... end

local presses = {}

local lib = {
    checks = setmetatable({}, {
        __index = object.module.checks,
        __newindex = function(t, k, v)
            if type(v) ~= "function" then
                error(("Attempted to assign a non-function value to %q (got: %s (%s))"):format(tostring(k), tostring(v), type(v)), 2)
            end
            object.module.checks[k] = v
        end
    }),
    is = object.module.is, isObject = object.module.is,
    new = object.module.new, newObject = object.module.new,
    root = root,
    class = class.module,
    init = function()
        if not love then return end
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
            if root.check(x, y) and b and not t then
                presses[b] = true
                return root.pressed(x, y, b) or old.mousepressed(...)
            end
        end
        love.mousemoved = function(...)
            local x, y, dx, dy, t = ...
            if not t then
                local r = false
                for b in pairs(presses) do
                    if type(b) == "number" then
                        if root.moved(x, y, dx, dy, b) then
                            r = true
                        else
                            presses[b] = nil
                        end
                    end
                end
                return r or old.mousemoved(...)
            end
        end
        love.mousereleased = function(...)
            local x, y, b, t = ...
            if b and not t and presses[b] then
                presses[b] = nil
                return root.released(x, y, b) or old.mousereleased(...)
            end
        end
        love.wheelmoved = function(...)
            local x, y = ...
            return root.check(love.mouse.getPosition()) and root.scrolled(y) or old.wheelmoved(...)
        end
        love.touchpressed = function(...)
            local id, x, y = ...
            if root.check(x, y) and root.pressed(x, y, id) then
                presses[id] = true
            else
                return old.touchpressed(...)
            end
        end
        love.touchmoved = function(...)
            local id, x, y, dx, dy = ...
            if presses[id] and not root.moved(x, y, dx, dy, id) then
                presses[id] = nil
                return old.touchmoved(...)
            end
        end
        love.touchreleased = function(...)
            local id, x, y = ...
            if presses[id] and root.released(x, y, id) then
                presses[id] = nil
            else
                return old.touchreleased(...)
            end
        end
    end
}

return setmetatable({}, {
	__index = lib,
	__newindex = emptyf,
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