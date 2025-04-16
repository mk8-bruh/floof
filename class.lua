local _PATH = (...):match("(.-)[^%.]+$")
local inj = {} -- dependency injection table

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

local class  = {}
local named  = setmetatable({}, {__mode = "v"}) -- { name : class }
local clrefs = setmetatable({}, {__mode = "k"}) -- { class: self  | object: class }
local supers = setmetatable({}, {__mode = "k"}) -- { class: super | object: super }

function class.is(o, c)
    return o and c and (clrefs[o] == c or class.is(class.super(o), c)) or o and clrefs[o] == o
end

function class.class(o)
    return o and clrefs[o]
end

function class.super(o)
    return o and supers[o]
end

function class.index(o, ...)
    if o and clrefs[o] then
        for k, i in ipairs{...} do
            o.indexes:push(i, k)
        end
    end
end

local function create(c, ...)
    local o = inj.object.new({}, c)
    if type(o.init) == "function" then
        o:init(...)
    end
    return o
end

local function new(_, ...)
    local arg = {...}
    if arg[1] and type(arg[1]) ~= "string" then
        table.insert(arg, 1, nil)
    end
    if arg[2] and clrefs[arg[2]] ~= arg[2] then
        table.insert(arg, 2, nil)
    end
    if type(arg[3]) ~= "table" or getmetatable(arg[3]) then
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
    local indexes
    if inj.array.is(c.indexes) then
        indexes = c.indexes
    else
        indexes = inj.array.new()
        if type(c.indexes) == "table" then
            for i, v in ipairs(c.indexes) do
                indexes:append(v)
            end
        end
    end
    c.name = nil
    c.indexes = nil
    return setmetatable(c, {
        __index = function(c, k)
            if k == "name" then
                return name
            elseif k == "indexes" then
                return indexes
            else
                return _index(indexes, c, k) or super[k] or class[k]
            end
        end,
        __newindex = function(c, k, v)
            if k == "name" then
                if type(v) == "string" then
                    if named[v] then
                        error(("A class named %q already exists"):format(v), 2)
                    end
                    name = v
                    named[v] = c
                elseif v == nil then
                    named[name] = nil
                    name = nil
                end
            elseif k ~= "indexes" and not class[k] then
                rawset(c, k, v)
            end
        end,
        __metatable = {},
        __tostring = function(c) return ("class: %s"):format(name) end,
        __call = create
    })
end

return setmetatable({}, {
    __index = function(_, k) return class[k] or named[k] end,
    __newindex = function() end,
	__metatable = {},
    __tostring = function() return "FLOOF class module" end,
    __call = new,
}), inj