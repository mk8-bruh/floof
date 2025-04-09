local _PATH = (...):match("(.-)[^%.]+$")
local object = require(_PATH .. ".object")

local class = {}
local classes = setmetatable({}, {__mode = "k"})
local named = setmetatable({}, {__mode = "v"})
local objects = setmetatable({}, {__mode = "k"})

function class.new(...)
    local arg = {...}
    if arg[1] and type(arg[1]) ~= "string" then
        table.insert(arg, 1, nil)
    end
    if arg[2] and not classes[arg[2]] then
        table.insert(arg, 2, nil)
    end
    if not type(arg[3]) == "table" then
        table.insert(arg, 3, {})
    end
    local name, super, blueprint = unpack(arg)
    local c = {}
    classes[c] = setmetatable({}, {mode = "k"})
    if name then named[name] = c end
    local int = {
        name = name,
        super = super,
        blueprint = blueprint
    }
    return setmetatable(c, {
        __index = function(c, k) return int[k] or class[k] end,
        __newindex = function() end,
        __call = class.new,
        __tostring = function(c) return ("class: %s"):format(c.name or tostring(c):match("table: (.+)") or tostring(c)) end
    })
end

function class.instantiate(c, ...)
    if not classes[c] then error(("Must specify a valid class object (received %s)"):format(type(c)), 2) end
    local o = c.super and c.super:new(...) or object.new()
    classes[c][o] = true
    objects[o] = self
    for k, v in pairs(self.blueprint) do
        o[k] = v
    end
    if type(o.init) == "function" then
        o:init(...)
    end
    return o
end

function class.is(c, o)
    return classes[c] and classes[c][o]
end

function class.classOf(o)
    return objects[o]
end

return setmetatable({}, {
    __index = function(t, k) return class[k] or named[k] end,
    __newindex = function() end,
	__metatable = {},
    __tostring = function(t) return "FLUFFI class module :3" end,
    __call = class.new,
})