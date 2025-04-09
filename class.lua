local _PATH = (...):match("(.-)[^%.]+$")
local object = require(_PATH .. ".object")

local class  = {}
local named  = setmetatable({}, {__mode = "v"}) -- { name : class }
local clrefs = setmetatable({}, {__mode = "k"}) -- { class: self  | object: class }
local supers = setmetatable({}, {__mode = "k"}) -- { class: super | object: super }

function class.is(o, u)
    return clrefs[o] == u
end

function class.class(o)
    return clrefs[o]
end

function class.super(o)
    return supers[o]
end

local function _create(c, ...)
    if not c then
        local o = object.new()
        o.indexes:push(class)
        return o, 0
    end
    local o, d = _create(supers[c], ...)
    o.indexes:push(c, 1)
    clrefs[o] = c
    supers[o] = supers[c]
    if type(o.init) == "function" then
        o:init(...)
    end
    return o, d + 1
end

local function create(c, ...)
    if not object[c] == c then error(("Must specify a valid class object (received %s)"):format(type(c)), 2) end
    local o, d = _create(c, ...)
    o.protectIndexes(-d, -1)
    return o
end

local function new(_, ...)
    local arg = {...}
    if arg[1] and type(arg[1]) ~= "string" then
        table.insert(arg, 1, nil)
    end
    if arg[2] and object[arg[2]] ~= arg[2] then
        table.insert(arg, 2, nil)
    end
    if not type(arg[3]) == "table" then
        table.insert(arg, 3, {})
    end
    local name, super, c = arg[1], arg[2], arg[3]
    if name then
        if named[name] then
            error(("A class named %q already exists"):format(name), 2)
        elseif class[k] then
            error(("Invalid class name: %q. Please choose a different name"):format(name), 2)
        else
            named[name] = c
        end
    end
    name = name or tostring(c):match("table: (.+)") or tostring(c)
    clrefs[c] = c
    supers[c] = super
    return setmetatable(c, {
        __metatable = {},
        __tostring = function(c) return ("class: %s"):format(name) end,
        __call = create
    })
end

return setmetatable({}, {
    __index = function(_, k) return class[k] or named[k] end,
    __newindex = function() end,
	__metatable = {},
    __tostring = function() return "FLUFFI class module :3" end,
    __call = new,
})