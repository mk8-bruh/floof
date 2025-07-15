-- FLOOF: Unified class system with object-oriented features
-- Copyright (c) 2024 Matus Kordos

local class = {}
local classes   = setmetatable({}, {__mode = "k"})
local named     = setmetatable({}, {__mode = "v"})
local instances = setmetatable({}, {__mode = "k"})

local function _index(indexes, t, k, visited)
    for i, index in ipairs(indexes) do
        local v
        if type(index) == "table" then
            v = index[k]
        elseif type(index) == "function" then
            local s, e = pcall(index, t, k)
            if not s then
                error(("Error while trying to access field %q of index #%d [%s]: %s"):format(k, i, tostring(index), e), 3)
            else
                v = e
            end
        end
        if v ~= nil then
            return v
        end
    end
end

local metamethods = {
    get = "index",
    set = "newindex",
    equals = "eq",
    lessthan = "lt", 
    lessequal = "le",
    add = "add",
    subtract = "sub",
    multiply = "mul",
    divide = "div",
    modulo = "mod",
    power = "pow",
    minus = "unm",
    concat = "concat",
    call = "call",
    tostring = "tostring"
}

local function getMetamethod(o, name)
    if not o then return end
    local ref = instances[o] or classes[o]
    return ref.meta[name] or getMetamethod(ref.class or ref.super, name)
end

local function _get(o, k)
    local ref = instances[o]
    
    if ref.getters[k] then
        return ref.getters[k](o)
    end
    
    local indexResult = _index(ref.indexes, o, k)
    if indexResult ~= nil then
        return indexResult
    end
    
    local rawResult = rawget(o, k)
    if rawResult ~= nil then
        return rawResult
    end
    
    local c = ref.class
    while c do
        local cref = classes[c]
        if cref.getters[k] then
            return cref.getters[k](o)
        end
        c = c.super
    end
    
    if ref.class[k] then return ref.class[k] end
    
    local meta = getMetamethod(o, "get")
    if meta then
        return meta(o, k)
    end
    
    return nil
end

local function _set(o, k, v)
    local ref = instances[o]
    
    if ref.setters[k] then
        return ref.setters[k](o, v)
    end
    
    local c = o
    while c do
        local cref = instances[c] or classes[c]
        if cref.setters[k] then
            return cref.setters[k](o, v)
        end
        c = c.class or c.super
    end
    
    c = o
    while c do
        local cref = instances[c] or classes[c]
        if cref.getters[k] then
            error(("Cannot assign value to property %q of %s as it has no setter defined"):format(k, tostring(c)), 2)
        end
        c = c.class or c.super
    end
    
    local meta = getMetamethod(o, "set")
    if meta then
        return meta(o, k, v)
    end
    
    rawset(o, k, v)
end

function class.isClass(c)
    return c ~= nil and classes[c] ~= nil
end

function class.isInstance(o)
    return o ~= nil and instances[o] ~= nil
end

function class.getClass(o)
    return class.isInstance(o) and instances[o].class
end

function class.isClassOf(c, o)
    return class.isClass(c) and (class.isInstance(o) and class.isInstanceOf(o, c) or class.isClass(o) and (o.super == c or class.isClassOf(c, o.super)))
end

function class.isInstanceOf(o, c)
    return class.isInstance(o) and class.isClass(c) and (o.class == c or class.isClassOf(c, o.class))
end

function class.index(o, ...)
    if not class.isInstance(o) and not class.isClass(o) then
        error("Indexing can only be done on classes or objects", 2)
    end
    local ref = instances[o] or classes[o]
    for i, index in ipairs{...} do
        if type(index) ~= "table" then
            error(("Index must be a table (got: %s (%s))"):format(tostring(index), type(index)), 2)
        end
        table.insert(ref.indexes, i, index)
    end
    return o
end

function class.getter(o, name, func)
    if type(name) ~= "string" then
        error(("Property name must be a string (got %s)"):format(tostring(name), type(name)), 2)
    end
    if not name:match("^[%a][_%w]*$") then
        error(("Invalid property name: %q (must start with a letter and contain only letters, numbers and underscores)"):format(name), 2)
    end
    if not class.isInstance(o) and not class.isClass(o) then
        error("Properties can only be added to classes or objects", 2)
    end
    if type(func) ~= "function" then
        error(("Property getter must be a function (got: %s)"):format(type(func)), 2)
    end
    local c = o
    while c do
        if rawget(c, name) then
            error(("Cannot override field %q (%s) of %s"):format(name, type(c[name]), tostring(c)), 2)
        end
        c = c.class or c.super or (c ~= class and class)
    end
    local ref = instances[o] or classes[o]
    ref.getters[name] = func
    return o
end

function class.setter(o, name, func)
    if type(name) ~= "string" then
        error(("Property name must be a string (got %s)"):format(tostring(name), type(name)), 2)
    end
    if not name:match("^[%a][_%w]*$") then
        error(("Invalid property name: %q (must start with a letter and contain only letters, numbers and underscores)"):format(name), 2)
    end
    if not class.isInstance(o) and not class.isClass(o) then
        error("Properties can only be added to classes or objects", 2)
    end
    if type(func) ~= "function" then
        error(("Property setter must be a function (got: %s)"):format(type(func)), 2)
    end
    local c = o
    while c do
        if rawget(c, name) then
            error(("Cannot override field %q (%s) of %s"):format(name, type(c[name]), tostring(c)), 2)
        end
        c = c.class or c.super or (c ~= class and class)
    end
    local ref = instances[o] or classes[o]
    ref.setters[name] = func
    return o
end

function class.property(o, name, getter, setter)
    if type(name) ~= "string" then
        error(("Property name must be a string (got %s)"):format(tostring(name), type(name)), 2)
    end
    if not name:match("^[%a][_%w]*$") then
        error(("Invalid property name: %q (must start with a letter and contain only letters, numbers and underscores)"):format(name), 2)
    end
    if not class.isInstance(o) and not class.isClass(o) then
        error("Properties can only be added to classes or objects", 2)
    end
    if getter and type(getter) ~= "function" then
        error(("Property getter must be a function (got: %s)"):format(type(getter)), 2)
    end
    if setter and type(setter) ~= "function" then
        error(("Property setter must be a function (got: %s)"):format(type(setter)), 2)
    end
    local c = o
    while c do
        if rawget(c, name) then
            error(("Cannot override field %q (%s) of %s"):format(name, type(c[name]), tostring(c)), 2)
        end
        c = c.class or c.super or (c ~= class and class)
    end
    local ref = instances[o] or classes[o]
    ref.getters[name] = getter
    ref.setters[name] = setter
    return o
end

function class.meta(o, name, func)
    if not metamethods[name] then
        error(("Unsupported metamethod: %q"):format(name), 2)
    end
    if not class.isInstance(o) and not class.isClass(o) then
        error("Metamethods can only be added to classes or objects", 2)
    end
    if type(func) ~= "function" then
        error(("Metamethod must be a function (got: %s)"):format(type(func)), 2)
    end
    local ref = instances[o] or classes[o]
    ref.meta[name] = func
    return o
end

local objectMt = {
    __index = function(o, k)
        local ref = instances[o]
        if type(k) ~= "string" then 
            local meta = getMetamethod(o, "get")
            if meta then
                return meta(o, k)
            end
            return rawget(o, k)
        elseif k == "id" or k == "class" or k == "indexes" then
            return ref[k]
        elseif k:match("^__") then
            return getMetamethod(o, k:sub(3))
        elseif k:match("^@get_(.+)") and ref.getters[k:match("^@get_(.+)")] then
            return ref.getters[k:match("^@get_(.+)")]
        elseif k:match("^@set_(.+)") and ref.setters[k:match("^@set_(.+)")] then
            return ref.setters[k:match("^@set_(.+)")]
        else
            return _get(o, k)
        end
    end,
    __newindex = function(o, k, v)
        local ref = instances[o]
        if type(k) ~= "string" then 
            local meta = getMetamethod(o, "set")
            if meta then
                meta(o, k, v)
            else
                rawset(o, k, v)
            end
        elseif k:match("^__") then
            local name = k:sub(3)
            if not metamethods[name] then
                error(("Unsupported metamethod: %q"):format(name), 2)
            end
            if type(v) ~= "function" then
                error(("Metamethod must be a function (got: %s)"):format(type(v)), 2)
            end
            o:meta(name, v)
        elseif k:match("^@get_(.+)") then
            local name = k:match("^@get_(.+)")
            if not name:match("^[%a][_%w]*$") then
                error(("Invalid property name: %q (must start with a letter and contain only letters, numbers and underscores)"):format(name), 2)
            end
            if type(v) ~= "function" then
                error(("Property getter must be a function (got: %s)"):format(type(v)), 2)
            end
            o:getter(name, v)
        elseif k:match("^@set_(.+)") then
            local name = k:match("^@set_(.+)")
            if not name:match("^[%a][_%w]*$") then
                error(("Invalid property name: %q (must start with a letter and contain only letters, numbers and underscores)"):format(name), 2)
            end
            if type(v) ~= "function" then
                error(("Property setter must be a function (got: %s)"):format(type(v)), 2)
            end
            o:setter(name, v)
        elseif ref[k] then
            error(("Cannot modify the %q field"):format(k), 2)
        else
            _set(o, k, v)
        end
    end,
    __metatable = false
}

for name, metamethod in pairs(metamethods) do
    if metamethod ~= "index" and metamethod ~= "newindex" then
        objectMt["__" .. metamethod] = function(o, ...)
            local meta = getMetamethod(o, name)
            if meta then
                return meta(o, ...)
            end
            if metamethod == "tostring" then
                return ("%s: %s"):format(o.class.name, instances[o].id)
            end
                        end
                    end
                end

function class.construct(c, ...)
    local obj = {}
    instances[obj] = {
        id = tostring(obj):match("table: (.+)") or tostring(obj),
        class = c,
        indexes = {},
        getters = {},
        setters = {},
        meta = {}
    }
    setmetatable(obj, objectMt)
    if type(obj.init) == "function" then
        obj:init(...)
    end
    return obj
end

local classMt = {
    __index = function(c, k)
        local ref = classes[c]
        if type(k) ~= "string" then 
            local meta = getMetamethod(c, "get")
            if meta then
                return meta(c, k)
            end
            return rawget(c, k)
        elseif k == "name" or k == "id" or k == "super" or k == "indexes" then
            return ref[k]
        elseif k:match("^__") then
            return getMetamethod(c, k:sub(3))
        elseif k:match("^@get_(.+)") and ref.getters[k:match("^@get_(.+)")] then
            return ref.getters[k:match("^@get_(.+)")]
        elseif k:match("^@set_(.+)") and ref.setters[k:match("^@set_(.+)")] then
            return ref.setters[k:match("^@set_(.+)")]
        else
            return _index(ref.indexes, c, k) or (ref.super and ref.super[k]) or class[k]
        end
    end,
    __newindex = function(c, k, v)
        local ref = classes[c]
        if type(k) ~= "string" then 
            local meta = getMetamethod(c, "set")
            if meta then
                meta(c, k, v)
            else
                rawset(c, k, v)
            end
        elseif k == "name" then
            if type(v) == "string" then
                if named[v] then
                    error(("A class named %q already exists"):format(v), 2)
                end
                if ref.name and named[ref.name] then
                    named[ref.name] = nil
                end
                ref.name = v
                named[v] = c
            elseif v == nil then
                if ref.name then
                    named[ref.name] = nil
                    ref.name = nil
                end
            else
                error(("Invalid value for class name (got: %s (%s))"):format(tostring(v), type(v)), 2)
            end
        elseif ref[k] or ref.getters[k] or ref.setters[k] or class[k] then
            error(("Cannot override the %q field"):format(tostring(k)), 2)
        elseif k:match("^__") then
            local name = k:sub(3)
            if not metamethods[name] then
                error(("Unsupported metamethod: %q"):format(name), 2)
            end
            if type(v) ~= "function" then
                error(("Metamethod must be a function (got: %s)"):format(type(v)), 2)
            end
            c:meta(name, v)
        elseif k:match("^@get_(.+)") then
            local name = k:match("^@get_(.+)")
            if not name:match("^[%a][_%w]*$") then
                error(("Invalid property name: %q (must start with a letter and contain only letters, numbers and underscores)"):format(name), 2)
            end
            if type(v) ~= "function" then
                error(("Property getter must be a function (got: %s)"):format(type(v)), 2)
            end
            c:getter(name, v)
        elseif k:match("^@set_(.+)") then
            local name = k:match("^@set_(.+)")
            if not name:match("^[%a][_%w]*$") then
                error(("Invalid property name: %q (must start with a letter and contain only letters, numbers and underscores)"):format(name), 2)
            end
            if type(v) ~= "function" then
                error(("Property setter must be a function (got: %s)"):format(type(v)), 2)
            end
            c:setter(name, v)
        else
            rawset(c, k, v)
        end
    end,
    __metatable = {},
    __tostring = function(c)
        local ref = classes[c]
        return ("class: %s"):format(ref.name or ref.id)
    end,
    __call = class.construct
}

for name, metamethod in pairs(metamethods) do
    if metamethod ~= "index" and metamethod ~= "newindex" and metamethod ~= "tostring" and metamethod ~= "call" then
        classMt["__" .. metamethod] = function(c, ...)
            local meta = getMetamethod(c, name)
            if meta then
                return meta(c, ...)
            end
        end
    end
end

return setmetatable({}, {
    __index = function(_, k) return class[k] or named[k] end,
    __newindex = function() end,
    __metatable = {},
    __tostring = function() return "<FLOOF class module>" end,
    __call = function(_, name, super, c)
        if name and type(name) ~= "string" then
            super, c, name = name, super
        end
        if super and not class.isClass(super) then
            c, super = super
        end
        c = type(c) == "table" and c or {}
        if not pcall(setmetatable, c, nil) then
            error("Classes with custom metatables are not supported. If you want to implement an indexing metatable/metamethod, use the 'indexes' field", 2)
        end
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
            id = tostring(c):match("table: (.+)") or tostring(c),
            name = name,
            super = super,
            getters = {},
            setters = {},
            indexes = {},
            meta = {}
        }
        classes[c] = ref
        local data = {}
        for k, v in pairs(c) do data[k], c[k] = v end
        setmetatable(c, classMt)
        for k, v in pairs(data) do
            local s, e = pcall(function() c[k] = v end)
            if not s then error(e, 2) end
        end
        return c
    end
})