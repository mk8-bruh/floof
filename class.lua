-- FLOOF: Unified class system with object-oriented features
-- Copyright (c) 2025 Matus Kordos

local class = {}
local classes   = setmetatable({}, {__mode = "k"})
local named     = setmetatable({}, {__mode = "v"})
local instances = setmetatable({}, {__mode = "k"})
local ids       = setmetatable({}, {__mode = "v"})

local function _index(indexes, t, k, visited)
    for i, index in ipairs(indexes) do
        local v
        if type(index) == "table" then
            v = index[k]
        elseif type(index) == "function" then
            local s, e = xpcall(index, debug.traceback, t, k)
            if not s then
                error(("Error while trying to access field %q of index #%d [%s]:\n%s"):format(k, i, tostring(index), e), 3)
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
    call = "call",
    tostring = "tostring",
    minus = "unm"
}

local operators = {
    equals = "eq",
    lessthan = "lt", 
    lessequal = "le",
    add = "add",
    subtract = "sub",
    multiply = "mul",
    divide = "div",
    modulo = "mod",
    power = "pow",
    concat = "concat"
}

local function getMetamethod(o, name)
    if class.isInstance(o) then
        local ref = instances[o]
        if ref.meta[name] then
            return ref.meta[name]
        end
        if ref.class then
            return getMetamethod(ref.class, name)
        end
    elseif class.isClass(o) then
        local ref = classes[o]
        if ref.meta[name] then
            return ref.meta[name]
        end
        if ref.super then
            return getMetamethod(ref.super, name)
        end
    end
    return nil
end

local function _get(o, k)
    if not o then return end
    local ref = instances[o] or classes[o]

    if class[k] then
        return class[k]
    end

    local rawResult = rawget(o, k)
    if rawResult ~= nil then
        return rawResult
    end
    
    if ref.getters[k] then
        return ref.getters[k](o)
    end
    
    local indexResult = _index(ref.indexes, o, k)
    if indexResult ~= nil then
        return indexResult
    end
    
    local c = ref.class or ref.super
    while c do
        local cref = classes[c]
        if cref.getters[k] then
            return cref.getters[k](o)
        end
        c = c.super
    end
    
    local meta = ref.meta.get
    if meta then
        local metaResult = meta(o, k)
        if metaResult ~= nil then
            return metaResult
        end
    end
    
    return _get(ref.class or ref.super, k)
end

local function _set(o, k, v)
    if not o then return end
    local ref = instances[o] or classes[o]
    
    if class[k] and k ~= "clone" then
        error(("Cannot assign value to %q as it is a reserved field"):format(k), 3)
    end

    if ref.setters[k] then
        return ref.setters[k](o, v)
    elseif ref.getters[k] then
        error(("Cannot assign value to property %q of %s as it is read-only"):format(k, tostring(o)), 3)
    end
    
    local c = ref.class or ref.super
    while c do
        local cref = instances[c] or classes[c]
        if cref.setters[k] then
            return cref.setters[k](o, v)
        end
        c = c.super
    end
    
    c = ref.class or ref.super
    while c do
        local cref = instances[c] or classes[c]
        if cref.getters[k] then
            error(("Cannot assign value to property %q of %s as it is read-only"):format(k, tostring(c)), 3)
        end
        c = c.super
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

function class.getInstance(id)
    return ids[id]
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
    if class.isInstance(o) and rawget(o, name) then
        error(("Cannot override field %q (%s)"):format(name, type(o[name])), 2)
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
    if class.isInstance(o) and rawget(o, name) then
        error(("Cannot override field %q (%s)"):format(name, type(o[name])), 2)
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
    if class.isInstance(o) and rawget(o, name) then
        error(("Cannot override field %q (%s)"):format(name, type(o[name])), 2)
    end
    local ref = instances[o] or classes[o]
    ref.getters[name] = getter
    ref.setters[name] = setter
    return o
end

function class.meta(o, name, func)
    if not metamethods[name] and not operators[name] then
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
        if k == "id" or k == "class" or k == "indexes" then
            return ref[k]
        elseif type(k) == "string" and k:match("^__get_(.+)") then
            local name = k:match("^__get_(.+)")
            return ref.getters[name] or (ref.class and ref.class[k]) or function(o) return o[name] end
        elseif type(k) == "string" and k:match("^__set_(.+)") then
            local name = k:match("^__set_(.+)")
            return ref.setters[name] or (ref.class and ref.class[k]) or function(o, v) o[name] = v end
        elseif type(k) == "string" and k:match("^__") then
            return getMetamethod(o, k:sub(3))
        else
            return _get(o, k)
        end
    end,
    __newindex = function(o, k, v)
        local ref = instances[o]
        if type(k) == "string" and k:match("^__get_(.+)") then
            local name = k:match("^__get_(.+)")
            if not name:match("^[%a][_%w]*$") then
                error(("Invalid property name: %q (must start with a letter and contain only letters, numbers and underscores)"):format(name), 2)
            end
            if type(v) ~= "function" then
                error(("Property getter must be a function (got: %s)"):format(type(v)), 2)
            end
            o:getter(name, v)
        elseif type(k) == "string" and k:match("^__set_(.+)") then
            local name = k:match("^__set_(.+)")
            if not name:match("^[%a][_%w]*$") then
                error(("Invalid property name: %q (must start with a letter and contain only letters, numbers and underscores)"):format(name), 2)
            end
            if type(v) ~= "function" then
                error(("Property setter must be a function (got: %s)"):format(type(v)), 2)
            end
            o:setter(name, v)
        elseif type(k) == "string" and k:match("^__") then
            local name = k:sub(3)
            if not metamethods[name] and not operators[name] then
                error(("Unsupported metamethod: %q"):format(name), 2)
            end
            if type(v) ~= "function" then
                error(("Metamethod must be a function (got: %s)"):format(type(v)), 2)
            end
            o:meta(name, v)
        elseif ref[k] then
            error(("Cannot modify the %q field"):format(k), 2)
        else
            _set(o, k, v)
        end
    end,
    __metatable = {}
}

function class.construct(c, ...)
    if c and not class.isClass(c) then
        error(("Invalid class (got: %s)"):format(tostring(c)), 2)
    end
    local obj = {}
    local id = tostring(obj):match("table: (.+)") or tostring(obj)
    instances[obj] = {
        id = id,
        class = c,
        indexes = {},
        getters = {},
        setters = {},
        meta = {}
    }
    ids[id] = obj
    setmetatable(obj, objectMt)
    if type(obj.init) == "function" then
        local s, e = xpcall(obj.init, debug.traceback, obj, ...)
        if not s then error(e, 2) end
        if c and c:isClassOf(e) then return e end
    end
    return obj
end

local classMt = {
    __index = function(c, k)
        local ref = classes[c]
        if k == "name" or k == "id" or k == "super" or k == "indexes" then
            return ref[k]
        elseif type(k) == "string" and k:match("^__get_(.+)") and ref.getters[k:match("^__get_(.+)")] then
            local name = k:match("^__get_(.+)")
            return ref.getters[name] or (ref.super and ref.super[k]) or function(o) return o[name] end
        elseif type(k) == "string" and k:match("^__set_(.+)") and ref.setters[k:match("^__set_(.+)")] then
            local name = k:match("^__set_(.+)")
            return ref.setters[name] or (ref.super and ref.super[k]) or function(o, v) o[name] = v end
        elseif type(k) == "string" and k:match("^__") then
            return getMetamethod(c, k:sub(3))
        elseif ids[k] and ids[k].class == c then
            return ids[k]
        else
            return _get(c, k)
        end
    end,
    __newindex = function(c, k, v)
        local ref = classes[c]
        if k == "name" then
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
        elseif ref[k] then
            error(("Cannot override the %q field"):format(tostring(k)), 2)
        elseif type(k) == "string" and k:match("^__get_(.+)") then
            local name = k:match("^__get_(.+)")
            if not name:match("^[%a][_%w]*$") then
                error(("Invalid property name: %q (must start with a letter and contain only letters, numbers and underscores)"):format(name), 2)
            end
            if type(v) ~= "function" then
                error(("Property getter must be a function (got: %s)"):format(type(v)), 2)
            end
            c:getter(name, v)
        elseif type(k) == "string" and k:match("^__set_(.+)") then
            local name = k:match("^__set_(.+)")
            if not name:match("^[%a][_%w]*$") then
                error(("Invalid property name: %q (must start with a letter and contain only letters, numbers and underscores)"):format(name), 2)
            end
            if type(v) ~= "function" then
                error(("Property setter must be a function (got: %s)"):format(type(v)), 2)
            end
            c:setter(name, v)
        elseif type(k) == "string" and k:match("^__") then
            local name = k:sub(3)
            if not metamethods[name] and not operators[name] then
                error(("Unsupported metamethod: %q"):format(name), 2)
            end
            if type(v) ~= "function" then
                error(("Metamethod must be a function (got: %s)"):format(type(v)), 2)
            end
            c:meta(name, v)
        else
            _set(c, k, v)
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
    if metamethod ~= "index" and metamethod ~= "newindex" then
        objectMt["__" .. metamethod] = function(o, ...)
            local meta = getMetamethod(o, name)
            if meta then
                local s, e = xpcall(meta, debug.traceback, o, ...)
                if not s then error(e, 2) end
                return e
            end
            if metamethod == "tostring" then
                local className = o.class and o.class.name or "object"
                return ("%s: %s"):format(className, o.id)
            end
            error(("Metamethod %q is not defined for %s"):format(name, tostring(o)), 2)
        end
    end
end

for name, operator in pairs(operators) do
    objectMt["__" .. operator] = function(a, b)
        local metaA, metaB = getMetamethod(a, name), getMetamethod(b, name)
        if metaA then
            local s, e = xpcall(metaA, debug.traceback, a, b)
            if not s then error(e, 2) end
            if e ~= nil then return e end
        end
        if metaB then
            local s, e = xpcall(metaB, debug.traceback, a, b)
            if not s then error(e, 2) end
            if e ~= nil then return e end
        end
        if name ~= "equals" and name ~= "lessthan" and name ~= "lessequal" then
            error(("Metamethod %q defined for %s and %s"):format(name, tostring(a), tostring(b)), 2)
        end
    end
end

local module = {}

function class.derive(super, name)
    if super == module then
        super = nil
    end
    if super and not class.isClass(super) then
        error(("Superclass must be a class (got: %s)"):format(tostring(super)), 2)
    end
    if name and type(name) ~= "string" then
        error(("Class name must be a string (got: %s)"):format(type(name)), 2)
    end
    local c = {}
    if name then
        if named[name] then
            error(("A class named %q already exists"):format(name), 2)
        elseif class[name] then
            error(("Invalid class name: %q. Please choose a different name"):format(name), 2)
        else
            named[name] = c
        end
    end
    classes[c] = {
        id = tostring(c):match("table: (.+)") or tostring(c),
        name = name,
        super = super,
        getters = {},
        setters = {},
        indexes = {},
        meta = {}
    }
    setmetatable(c, classMt)
    if type(c.setup) == "function" then
        local s, e = xpcall(c.setup, debug.traceback, c)
        if not s then error(e, 2) end
    end
    return c
end

function class.clone(obj)
    if not class.isInstance(obj) then
        error(("Invalid object: %s"):format(tostring(obj)), 2)
    end
    
    local ref = instances[obj]
    local clone = {}
    
    -- Create new instance reference
    instances[clone] = {
        id = tostring(clone):match("table: (.+)") or tostring(clone),
        class = ref.class,
        indexes = {},
        getters = {},
        setters = {},
        meta = {}
    }

    -- Copy all raw fields
    for k, v in pairs(obj) do
        rawset(clone, k, v)
    end
    
    -- Copy indexes (shallow copy)
    for i, index in ipairs(ref.indexes) do
        instances[clone].indexes[i] = index
    end
    
    -- Copy getters and setters
    for k, v in pairs(ref.getters) do
        instances[clone].getters[k] = v
    end
    for k, v in pairs(ref.setters) do
        instances[clone].setters[k] = v
    end
    
    -- Copy metamethods
    for k, v in pairs(ref.meta) do
        instances[clone].meta[k] = v
    end
    
    -- Set metatable
    setmetatable(clone, objectMt)
    
    return clone
end

return setmetatable(module, {
    __index = function(_, k) return class[k] or named[k] end,
    __newindex = function() end,
    __metatable = {},
    __tostring = function() return "<FLOOF class module>" end,
    __call = class.derive
})