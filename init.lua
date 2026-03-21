-- FLOOF: Fast Lua Object-Oriented Framework
-- Copyright (c) 2026 Matus Kordos

local methods, module = {}, {}
local classes   = setmetatable({}, {__mode = "k"})
local named     = setmetatable({}, {__mode = "v"})
local instances = setmetatable({}, {__mode = "k"})
local ids       = setmetatable({}, {__mode = "v"})

local metamethods = {
    init = "",
    setup = "",
    get = "",
    set = "",
    call = "call",
    tostring = "tostring",
    invert = "unm"
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

function methods.isClass(c)
    return classes[c] ~= nil
end

function methods.isInstance(o)
    return instances[o] ~= nil
end

function methods.getClass(o)
    return instances[o] and instances[o].class
end

function methods.getInstance(id)
    return ids[id]
end

function methods.instanceOf(o, c)
    local s = instances[o] and instances[o].class
    if not s and c == module then return true end
    while s do
        if s == c then return true end
        s = classes[s].super
    end
    return false
end

function methods.subclassOf(s, c)
    local s = classes[s] and s
    while s do
        if s == c then return true end
        s = classes[s].super
    end
    return false
end

local inf, nan = math.huge, 0/0
function methods.typeOf(o)
    return instances[o] and (instances[o].class and classes[instances[o].class].name or "instance") or
           classes[o] and ("class: %s"):format(classes[o].name) or
           --o == nan and "nan" or o == inf and "inf" or o == -inf and "-inf" or
           type(o)
end

function methods.isCallable(f)
    local mt = getmetatable(f)
    return type(f) == "function" or
           classes[f] or
           instances[f] and instances[f].meta.call or
           type(mt) == "table" and mt.__call
end

function methods.getNamed(n) return named[n] end

local function successEval(l, s, ...) if s then return ... else error(..., l) end end
function methods.safeInvoke(f, ...)
    if methods.isCallable(f) then
        return successEval(3, pcall(f, ...))
    else
        return f
    end
end
function methods.safeReturn(f, ...)
    if methods.isCallable(f) then
        return successEval(2, pcall(f, ...))
    else
        return f
    end
end

function methods.supportsArithmetic(v, f)
    if f == "concat" or f ~= "invert" and not operators[f] then return false end
    local mt = getmetatable(f)
    return type(v) == "number" or
           instances[v] and instances[v].meta[f] or
           type(mt) == "table" and mt["__"..(f == "invert" and metamethods[f] or operators[f])]
end

function methods.getter(o, name, func)
    if not methods.isInstance(o) and not methods.isClass(o) then
        error(("Invalid caller: class or instance expected, got %s"):format(methods.typeOf(o)), 2)
    end
    if type(name) ~= "string" then
        error(("Invalid name: string expected, got %s"):format(methods.typeOf(name)), 2)
    end
    if not name:match("^[%a][_%w]*$") then
        error(("Invalid property name (%q): must start with a letter and contain only letters, numbers and underscores"):format(name), 2)
    end
    if not methods.isCallable(func) and func ~= nil then
        error(("Invalid getter: callable expected, got %s"):format(methods.typeOf(func)), 2)
    end
    local ref = instances[o] or classes[o]
    ref.getters[name] = func
    return o
end

function methods.getGetter(o, name)
    if not methods.isInstance(o) and not methods.isClass(o) then
        error(("Invalid caller: class or instance expected, got %s"):format(methods.typeOf(o)), 2)
    end
    local ref = instances[o] or classes[o]
    while ref do
        if ref.getters[name] then
            return ref.getters[name]
        end
        ref = classes[ref.class or ref.super]
    end
end

function methods.setter(o, name, func)
    if not methods.isInstance(o) and not methods.isClass(o) then
        error("Object is not a class or instance", 2)
    end
    if type(name) ~= "string" then
        error(("Property name must be a string (got %s)"):format(tostring(name), type(name)), 2)
    end
    if not name:match("^[%a][_%w]*$") then
        error(("Invalid property name: %q (must start with a letter and contain only letters, numbers and underscores)"):format(name), 2)
    end
    if type(func) ~= "function" and func ~= nil then
        error(("Property setter must be a function (got: %s)"):format(type(func)), 2)
    end
    local ref = instances[o] or classes[o]
    ref.setters[name] = func
    return o
end

function methods.getSetter(o, name)
    if not methods.isInstance(o) and not methods.isClass(o) then
        error(("Invalid caller: class or instance expected, got %s"):format(methods.typeOf(o)), 2)
    end
    local ref = instances[o] or classes[o]
    while ref do
        if ref.setters[name] then
            return ref.setters[name]
        end
        ref = classes[ref.class or ref.super]
    end
end

function methods.property(o, name, getter, setter)
    if not methods.isInstance(o) and not methods.isClass(o) then
        error("Object is not a class or instance", 2)
    end
    if type(name) ~= "string" then
        error(("Property name must be a string (got %s)"):format(tostring(name), type(name)), 2)
    end
    if not name:match("^[%a][_%w]*$") then
        error(("Invalid property name: %q (must start with a letter and contain only letters, numbers and underscores)"):format(name), 2)
    end
    if type(getter) ~= "function" and getter ~= nil then
        error(("Property getter must be a function (got: %s)"):format(type(getter)), 2)
    end
    if type(setter) ~= "function" and setter ~= nil then
        error(("Property setter must be a function (got: %s)"):format(type(setter)), 2)
    end
    if o:isClass() then
        for _, i in ipairs(o:instances()) do
            rawset(i, name, nil)
        end
    elseif o:isInstance() then
        rawset(o, name, nil)
    end
    local ref = instances[o] or classes[o]
    ref.getters[name] = getter
    ref.setters[name] = setter
    return o
end

function methods.getProperty(o, name)
    if not methods.isInstance(o) and not methods.isClass(o) then
        error(("Invalid caller: class or instance expected, got %s"):format(methods.typeOf(o)), 2)
    end
    local ref = instances[o] or classes[o]
    local g, s
    while ref do
        if not g and ref.getters[name] then
            g = ref.getters[name]
        end
        if not s and ref.setters[name] then
            s = ref.setters[name]
        end
        if g and s then break end
        ref = classes[ref.class or ref.super]
    end
    return g, s
end

function methods.meta(o, name, func)
    if not methods.isInstance(o) and not methods.isClass(o) then
        error("Object is not a class or instance", 2)
    end
    if not metamethods[name] and not operators[name] then
        error(("Unsupported metamethod: %q"):format(name), 2)
    end
    if type(func) ~= "function" and func ~= nil then
        error(("Metamethod must be a function (got: %s)"):format(type(func)), 2)
    end
    local ref = instances[o] or classes[o]
    ref.meta[name] = func
    return o
end

function methods.getMeta(o, name)
    if not methods.isInstance(o) and not methods.isClass(o) then
        error("Object is not a class or instance", 2)
    end
    local ref = instances[o] or classes[o]
    while ref do
        if ref.meta[name] then
            return ref.meta[name]
        end
        ref = classes[ref.class or ref.super]
    end
end

function methods.get(...)
    local s, o, k
    if classes[...] and instances[select(2, ...)] then
        s, o, k = ...
    else
        o, k = ...
        s = o
    end
    if not (instances[o] or classes[o]) then
        error(("Invalid object: class or instance expected, got %s"):format(methods.typeOf(o)), 2)
    end
    local ref = instances[s] or classes[s]
    if not ref then
        error(("Invalid source: class or instance expected, got %s"):format(methods.typeOf(s)), 2)
    end
    if k == "id" or k == "super" or (instances[o] and k == "class") or (classes[o] and k == "name") then
        return ref[k]
    elseif type(k) == "string" and k:match("^__get_(.+)") then
        local name = k:match("^__get_(.+)")
        return methods.getGetter(s, name)
    elseif type(k) == "string" and k:match("^__set_(.+)") then
        local name = k:match("^__set_(.+)")
        return methods.getSetter(s, name)
    elseif type(k) == "string" and k:match("^__(.+)") then
        local name = k:match("^__(.+)")
        return methods.getMeta(s, name)
    end
    while s do
        if ref.getters[k] then
            return methods.safeReturn(ref.getters[k], o)
        end
        local rawResult = rawget(s, k)
        if rawResult ~= nil then return rawResult end
        if ref.meta.get then
            local metaResult = methods.safeInvoke(ref.meta.get, o, k)
            if metaResult ~= nil then return metaResult end
            break
        end
        s = ref.class or ref.super
        ref = classes[s]
    end
    return methods[k]
end

function methods.set(...)
    local s, o, k, v
    if classes[...] and instances[select(2, ...)] then
        s, o, k, v = ...
    else
        o, k, v = ...
        s = o
    end
    if not (instances[o] or classes[o]) then
        error(("Invalid object: class or instance expected, got %s"):format(methods.typeOf(o)), 2)
    end
    local ref = instances[s] or classes[s]
    if not ref then
        error(("Invalid source: class or instance expected, got %s"):format(methods.typeOf(s)), 2)
    end
    if type(k) == "string" and k:match("^__get_(.+)") then
        local name = k:match("^__get_(.+)")
        return methods.safeReturn(methods.getter, o, name, v)
    elseif type(k) == "string" and k:match("^__set_(.+)") then
        local name = k:match("^__set_(.+)")
        return methods.safeReturn(methods.setter, o, name, v)
    elseif type(k) == "string" and k:match("^__(.+)") then
        local name = k:match("^__(.+)")
        return methods.safeReturn(methods.meta, o, name, v)
    elseif ref[k] then
        error(("Field %s is protected and cannot be modified"):format(k), 2)
    end
    while s do
        if ref.setters[k] then
            return methods.safeReturn(ref.setters[k], o, v)
        elseif ref.getters[k] then
            error(("Cannot assign value to property %q of %s as it is read-only"):format(k, tostring(c)), 2)
        elseif ref.meta.set then
            return methods.safeReturn(ref.meta.set, o, k, v)
        end
        s = ref.class or ref.super
        ref = classes[s]
    end
    rawset(o, k, v)
end

local objectMt = {
    __index = methods.get,
    __newindex = methods.set,
    __metatable = {}
}

for name, metamethod in pairs(metamethods) do
    if metamethod ~= "" then
        objectMt["__" .. metamethod] = function(o, ...)
            local meta = methods.getMeta(o, name)
            if meta then
                return methods.safeReturn(meta, o, ...)
            end
            if metamethod == "tostring" then
                local className =
                    instances[o].class and
                    classes[instances[o].class].name
                    or "instance"
                return ("%s: %s"):format(className, o.id)
            end
            error(("Metamethod %q is not defined for %s"):format(name, tostring(o)), 2)
        end
    end
end

for name, operator in pairs(operators) do
    objectMt["__" .. operator] = function(a, b)
        local metaA, metaB =
            methods.isInstance(a) and methods.getMeta(a, name),
            methods.isInstance(b) and methods.getMeta(b, name)
        if metaA then return methods.safeReturn(metaA, a, b)
        elseif metaB then return methods.safeReturn(metaB, a, b)
        elseif name == "equals" then return instances[a] and instances[b] and instances[a] == instances[b]
        else error(("Operator %q not implemented"):format(name), 2) end
    end
end

function methods.construct(c, ...)
    if c ~= module and not methods.isClass(c) then
        error(("Invalid class (got: %s)"):format(tostring(c)), 2)
    end
    local obj = {}
    local id = tostring(obj):match("table: (.+)") or tostring(obj)
    instances[obj] = {
        id = id,
        class = c ~= module and c or nil,
        super = c ~= module and classes[c].super or nil,
        getters = {},
        setters = {},
        meta = {}
    }
    ids[id] = obj
    setmetatable(obj, objectMt)
    local init = methods.getMeta(obj, "init")
    if init then
        local r = methods.safeInvoke(init, obj, ...)
        if methods.instanceOf(r, c) then return r end
    end
    return obj
end

local classMt = {
    __index = methods.get,
    __newindex = methods.set,
    __metatable = {},
    __tostring = function(c)
        local ref = classes[c]
        return ("class: %s"):format(ref.name or ref.id)
    end,
    __call = methods.construct
}

function methods.class(super, name)
    if super == module then
        super = nil
    end
    if super and not methods.isClass(super) then
        error(("Superclass must be a class (got: %s)"):format(tostring(super)), 2)
    end
    if name and type(name) ~= "string" then
        error(("Class name must be a string (got: %s)"):format(type(name)), 2)
    end
    local c = {}
    if name then
        if named[name] then
            error(("A class named %q already exists"):format(name), 2)
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
        meta = {}
    }
    setmetatable(c, classMt)
    local setup = methods.getMeta(c, "setup")
    if setup then methods.safeInvoke(setup, c) end
    return c
end

function methods.iterate(start, factory, includeStart)
    if not methods.isCallable(factory) then
        error(("Invalid factory: callable expected, got %s"):format(methods.typeOf(factory)), 2)
    end
    local state = {}
    local curr = start
    state[state] = start
    while curr do
        local nxt = methods.safeInvoke(factory, curr, start)
        if curr == nxt or state[nxt] then
            error(("Duplicate iteration value: %s (values must be unique)"):format(tostring(nxt)), 2)
        end
        curr, state[curr] = nxt, nxt
    end
    return rawget, state, includeStart and state or start
end

function methods.newIterator(factory)
    if not methods.isCallable(factory) then
        error(("Invalid factory: callable expected, got %s"):format(methods.typeOf(factory)), 2)
    end
    return function(start, includeStart)
        local state = {}
        local curr = start
        state[state] = start
        while curr do
            local nxt = methods.safeInvoke(factory, curr, start)
            if curr == nxt or state[nxt] then
                error(("Duplicate iteration value: %s (values must be unique)"):format(tostring(nxt)), 2)
            end
            curr, state[curr] = nxt, nxt
        end
        return rawget, state, includeStart and state or start
    end
end

function methods.instances()
    return methods.iterate(factory(instances), function(self) return factory(instances, self) end)
end

function methods.instancesOf(cls)
    return methods.iterate(factory(instances), function(self)
        repeat self = factory(instances, self) until not self or methods.instanceOf(self, cls)
        return self
    end)
end

function methods.directInstancesOf(cls)
    return methods.iterate(factory(instances), function(self)
        repeat self = factory(instances, self) until not self or instances[self].class == cls
        return self
    end)
end

local PATH = ...
local submodules = {
    array   = false,
    vector  = false,
    object  = false,
    element = false
}

return setmetatable(module, {
    __index = function(t, k)
        if submodules[k] then
            return submodules[k]
        elseif submodules[k] == false then
            submodules[k] = require(PATH..".".. k)
            return submodules[k]
        else
            return methods[k] or named[k]
        end
    end,
    __newindex = function() end,
    __metatable = {},
    __tostring = function() return "<FLOOF module>" end,
    __call = methods.class
})