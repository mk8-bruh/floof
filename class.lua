local _PATH = (...):match("(.-)[^%.]+$")
local inj = {} -- dependency injection table

-- dummy functions
local emptyf = function(...) return end
local setk      = function(t, k, v) t[k] = v end

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
local classes = setmetatable({}, {__mode = "k"})
local named   = setmetatable({}, {__mode = "v"})

function class.is(o, c)
    return  inj.object.is(o) and class.is(c) and (o.class == c or class.is(o.class.super, c)) or
            o and classes[o] ~= nil
end

function class.index(o, ...)
    if inj.object.is(o) or class.is(o) then
        for k, i in ipairs{...} do
            o.indexes:push(i, k)
        end
    end
end

local classMt = {
    __index = function(c, k)
        local ref = c and classes[c]
        if not ref then return end
        return  k == "name" and ref.name or
                k == "super" and ref.super or
                k == "check" and ref.check or
                k == "indexes" and ref.indexes or
                ref.callbacks[k] or
                _index(ref.indexes, c, k) or
                ref.super and ref.super[k] or
                class[k]
    end,
    __newindex = function(c, k, v)
        local ref = c and classes[c]
        if not ref then return end
        if k == "name" then
            if type(v) == "string" then
                if named[v] then
                    error(("A class named %q already exists"):format(v), 2)
                end
                if named[ref.name] then named[name] = nil end
                ref.name = v
                named[v] = c
            elseif v == nil then
                named[ref.name] = nil
                ref.name = tostring(c):match("table: (.+)") or tostring(c)
            else
                error(("Invalid value for class name (got: %s (%s))"):format(tostring(v), type(v)), 2)
            end
        elseif k == "check" then
            if v == nil then
                ref.check = nil
            elseif type(v) == "boolean" then
                ref.check = function() return v end
            elseif type(v) == "function" then
                ref.check = v
            else
                error(("Cannot assign non-function value to %q (got: %s (%s))"):format(k, tostring(v), type(v)), 2)
            end
        elseif k == "indexes" then
            if type(v) == "table" then
                c:index(unpack(v))
            else
                error(("%q must be assigned an array of index tables (got: %s (%s))"):format(k, tostring(v), type(v)), 2)
            end
        elseif inj.object.callbackNames[k] then
            if v == nil then
                ref.callbacks[k] = nil
            elseif type(v) == "boolean" then
                ref.callbacks[k] = function() return v end
            elseif type(v) == "function" then
                ref.callbacks[k] = v
            else
                error(("Cannot assign non-function value to %q (got: %s (%s))"):format(k, tostring(v), type(v)), 2)
            end
        elseif class[k] then
            error(("Cannot override the %q method"):format(tostring(k)), 2)
        else
            rawset(c, k, v)
        end
    end,
    __metatable = {},
    __tostring = function(c)
        local ref = c and classes[c]
        if not ref then return end
        return ("class: %s"):format(ref.name)
    end,
    __call = function(c, ...)
        return inj.object.new({}, c, ...)
    end
}

local function new(_, name, super, c)
    if name and type(name) ~= "string" then
        super, c, name = name, super
    end
    if super and not class.is(super) then
        c, super = super
    end
    c = type(c) == "table" and c or {}
    if not pcall(setmetatable, c, nil) then
        error("Classes with custom metatables are not supported. If you want to implement an indexing metatable/metamethod, use the 'indexes' field", 2)
    end
    name = name or tostring(c):match("table: (.+)") or tostring(c)
    if name then
        if named[name] then
            error(("A class named %q already exists"):format(name), 2)
        elseif class[k] then
            error(("Invalid class name: %q. Please choose a different name"):format(name), 2)
        else
            named[name] = c
        end
    end
    local ref = {
        name = name,
        super = super,
        check = nil,
        indexes = inj.array.new(),
        callbacks = {}
    }
    classes[c] = ref
    local data = {}
    for k, v in pairs(c) do data[k], c[k] = v end
    setmetatable(c, classMt)
    for k, v in pairs(data) do
        local s, e = pcall(setk, c, k, v)
        if not s then error(e, 2) end
    end
    return c
end

return {
    module = setmetatable({}, {
        __index = function(_, k) return class[k] or named[k] end,
        __newindex = function() end,
        __metatable = {},
        __tostring = function() return "FLOOF class module" end,
        __call = new,
    }),
    inj = inj
}