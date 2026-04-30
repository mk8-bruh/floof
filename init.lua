-- FLOOF: Fast Lua Object-Oriented Framework
-- Copyright (c) 2026 Matus Kordos

local methods, module = {}, {}
local named = setmetatable({}, {__mode = "v"})
local ids   = setmetatable({}, {__mode = "v"})
local refs  = setmetatable({}, {__mode = "k"})

local metamethods = {
    init     = "",
    setup    = "",
    get      = "",
    set      = "",
    call     = "call",
    tostring = "tostring",
    invert   = "unm"
}

local operators = {
    equals    = "eq",
    lessthan  = "lt",
    lessequal = "le",
    add       = "add",
    subtract  = "sub",
    multiply  = "mul",
    divide    = "div",
    modulo    = "mod",
    power     = "pow",
    concat    = "concat"
}

function methods.isClass(object)
    return refs[object] and refs[object].type == "class" or false
end

function methods.isInstance(object)
    return refs[object] and refs[object].type == "instance" or false
end

function methods.getClass(object)
    return refs[object] and refs[object].class
end

function methods.getInstance(id)
    return ids[id]
end

function methods.instanceOf(object, class)
    if not refs[object] or refs[object].type ~= "instance" then return refs[class] == nil end
    local currentClass = refs[object].class
    if not currentClass and class == module then return true end
    while currentClass do
        if currentClass == class then return true end
        currentClass = refs[currentClass].super
    end
    return false
end

function methods.subclassOf(class, super)
    if not refs[class] or refs[class].type ~= "class" then return refs[super] == nil end
    if super == module then return true end
    local currentClass = refs[class] and refs[class].super
    while currentClass do
        if currentClass == super then return true end
        currentClass = refs[currentClass].super
    end
    return false
end

function methods.typeOf(value)
    local ref = refs[value]
    if ref then
        if ref.type == "instance" then
            return ref.class and refs[ref.class].name or "instance"
        else
            return ("class: %s"):format(ref.name)
        end
    end
    return type(value)
end

function methods.isCallable(value)
    local ref, mt = refs[value], getmetatable(value)
    return type(value) == "function" or
           (ref and ref.type == "class") or
           (ref and ref.meta and ref.meta.call) or
           (type(mt) == "table" and mt.__call)
end

function methods.getNamed(name) return named[name] end

local function successEval(level, success, ...)
    if success then return ... else error(..., level) end
end
function methods.safeInvoke(func, ...)
    if methods.isCallable(func) then
        return successEval(3, pcall(func, ...))
    else
        return func
    end
end
function methods.safeReturn(func, ...)
    if methods.isCallable(func) then
        return successEval(2, pcall(func, ...))
    else
        return func
    end
end

function methods.supportsArithmetic(value, op)
    if op == "concat" or op ~= "invert" and not operators[op] then return false end
    local ref, mt = refs[value], getmetatable(value)
    return type(value) == "number" or
           (ref and ref.type == "instance" and ref.meta[op]) or
           (type(mt) == "table" and mt["__"..(op == "invert" and metamethods[op] or operators[op])])
end

function methods.getter(object, name, func)
    if not methods.isInstance(object) and not methods.isClass(object) then
        error(("Invalid caller: class or instance expected, got %s"):format(methods.typeOf(object)), 2)
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
    refs[object].getters[name] = func
    return object
end

function methods.getGetter(object, name)
    if not methods.isInstance(object) and not methods.isClass(object) then
        error(("Invalid caller: class or instance expected, got %s"):format(methods.typeOf(object)), 2)
    end
    local ref = refs[object]
    while ref do
        if ref.getters[name] then return ref.getters[name] end
        ref = refs[ref.class or ref.super]
    end
end

function methods.setter(object, name, func)
    if not methods.isInstance(object) and not methods.isClass(object) then
        error(("Invalid caller: class or instance expected, got %s"):format(methods.typeOf(object)), 2)
    end
    if type(name) ~= "string" then
        error(("Invalid name: string expected, got %s"):format(methods.typeOf(name)), 2)
    end
    if not name:match("^[%a][_%w]*$") then
        error(("Invalid property name (%q): must start with a letter and contain only letters, numbers and underscores"):format(name), 2)
    end
    if type(func) ~= "function" and func ~= nil then
        error(("Invalid setter: function expected, got %s"):format(methods.typeOf(func)), 2)
    end
    refs[object].setters[name] = func
    return object
end

function methods.getSetter(object, name)
    if not methods.isInstance(object) and not methods.isClass(object) then
        error(("Invalid caller: class or instance expected, got %s"):format(methods.typeOf(object)), 2)
    end
    local ref = refs[object]
    while ref do
        if ref.setters[name] then return ref.setters[name] end
        ref = refs[ref.class or ref.super]
    end
end

function methods.property(object, name, getter, setter)
    if not methods.isInstance(object) and not methods.isClass(object) then
        error(("Invalid caller: class or instance expected, got %s"):format(methods.typeOf(object)), 2)
    end
    if type(name) ~= "string" then
        error(("Invalid name: string expected, got %s"):format(methods.typeOf(name)), 2)
    end
    if not name:match("^[%a][_%w]*$") then
        error(("Invalid property name (%q): must start with a letter and contain only letters, numbers and underscores"):format(name), 2)
    end
    if type(getter) ~= "function" and getter ~= nil then
        error(("Invalid getter: function expected, got %s"):format(methods.typeOf(getter)), 2)
    end
    if type(setter) ~= "function" and setter ~= nil then
        error(("Invalid setter: function expected, got %s"):format(methods.typeOf(setter)), 2)
    end
    if methods.isClass(object) then
        for instance in methods.instancesOf(object) do rawset(instance, name, nil) end
    elseif methods.isInstance(object) then
        rawset(object, name, nil)
    end
    local ref = refs[object]
    ref.getters[name] = getter
    ref.setters[name] = setter
    return object
end

function methods.getProperty(object, name)
    if not methods.isInstance(object) and not methods.isClass(object) then
        error(("Invalid caller: class or instance expected, got %s"):format(methods.typeOf(object)), 2)
    end
    local ref = refs[object]
    local foundGetter, foundSetter
    while ref do
        if not foundGetter and ref.getters[name] then foundGetter = ref.getters[name] end
        if not foundSetter and ref.setters[name] then foundSetter = ref.setters[name] end
        if foundGetter and foundSetter then break end
        ref = refs[ref.class or ref.super]
    end
    return foundGetter, foundSetter
end

function methods.meta(object, name, func)
    if not methods.isInstance(object) and not methods.isClass(object) then
        error(("Invalid caller: class or instance expected, got %s"):format(methods.typeOf(object)), 2)
    end
    if not metamethods[name] and not operators[name] then
        error(("Unsupported metamethod: %q"):format(name), 2)
    end
    if type(func) ~= "function" and func ~= nil then
        error(("Invalid metamethod: function expected, got %s"):format(methods.typeOf(func)), 2)
    end
    refs[object].meta[name] = func
    return object
end

function methods.getMeta(object, name)
    if not methods.isInstance(object) and not methods.isClass(object) then
        error(("Invalid caller: class or instance expected, got %s"):format(methods.typeOf(object)), 2)
    end
    local ref = refs[object]
    while ref do
        if ref.meta[name] then return ref.meta[name] end
        ref = refs[ref.class or ref.super]
    end
end

function methods.get(...)
    local a, b, c = ...
    local source, object, key
    if (
        refs[a] and refs[a].type == "class"
    ) and (
        refs[b] --and refs[b].type == "instance"
    ) then
        source, object, key = a, b, c
    else
        source, object, key = a, a, b
    end
    if not refs[source] then
        error(("Invalid source: class or instance expected, got %s"):format(methods.typeOf(source)), 2)
    end
    local ref = refs[object]
    if not ref then
        error(("Invalid object: class or instance expected, got %s"):format(methods.typeOf(object)), 2)
    end
    local isInst = ref.type == "instance"
    if key == "id" or key == "super" or (isInst and key == "class") or (not isInst and key == "name") then
        return ref[key]
    elseif type(key) == "string" and key:match("^__get_(.+)") then
        return methods.getGetter(object, key:match("^__get_(.+)"))
    elseif type(key) == "string" and key:match("^__set_(.+)") then
        return methods.getSetter(object, key:match("^__set_(.+)"))
    elseif type(key) == "string" and key:match("^__(.+)") then
        return methods.getMeta(object, key:match("^__(.+)"))
    end
    while source do
        ref = refs[source]
        if ref.getters[key] then
            return methods.safeReturn(ref.getters[key], object)
        end
        local rawResult = rawget(source, key)
        if rawResult ~= nil then return rawResult end
        if ref.meta.get then
            local metaResult = methods.safeInvoke(ref.meta.get, object, key)
            if metaResult ~= nil then return metaResult end
            break
        end
        source = ref.class or ref.super
    end
    return methods[key]
end

function methods.set(...)
    local a, b, c, d = ...
    local source, object, key, value
    if (
        refs[a] and refs[a].type == "class"
    ) and (
        refs[b] --and refs[b].type == "instance"
    ) then
        source, object, key, value = a, b, c, d
    else
        source, object, key, value = a, a, b, c
    end
    if not refs[source] then
        print(...) -- this prints "class: Object" and "class: Element" which means the refs have to be working inside of the print statement
        error(("Invalid source: class or instance expected, got %s"):format(methods.typeOf(source)), 2)
    end
    if not refs[object] then
        error(("Invalid object: class or instance expected, got %s"):format(methods.typeOf(object)), 2)
    end
    if type(key) == "string" and key:match("^__get_(.+)") then
        return methods.safeReturn(methods.getter, object, key:match("^__get_(.+)"), value)
    elseif type(key) == "string" and key:match("^__set_(.+)") then
        return methods.safeReturn(methods.setter, object, key:match("^__set_(.+)"), value)
    elseif type(key) == "string" and key:match("^__(.+)") then
        return methods.safeReturn(methods.meta, object, key:match("^__(.+)"), value)
    elseif refs[object][key] then
        error(("Field %q is protected and cannot be modified"):format(key), 2)
    end
    while source do
        local ref = refs[source]
        if ref.setters[key] then
            return methods.safeReturn(ref.setters[key], object, value)
        elseif ref.getters[key] then
            error(("Property %q of %s is read-only"):format(key, tostring(object)), 2)
        elseif ref.meta.set then
            return methods.safeReturn(ref.meta.set, object, key, value)
        end
        source = ref.class or ref.super
    end
    rawset(object, key, value)
end

local objectMt = {
    __index     = methods.get,
    __newindex  = methods.set,
    __metatable = {}
}

for name, metamethod in pairs(metamethods) do
    if metamethod ~= "" then
        objectMt["__" .. metamethod] = function(object, ...)
            local meta = methods.getMeta(object, name)
            if meta then return methods.safeReturn(meta, object, ...) end
            if metamethod == "tostring" then
                local ref = refs[object]
                return ("%s: %s"):format(
                    ref.class and refs[ref.class].name or "instance",
                    ref.id
                )
            end
            error(("Metamethod %q is not defined for %s"):format(name, tostring(object)), 2)
        end
    end
end

for name, operator in pairs(operators) do
    objectMt["__" .. operator] = function(a, b)
        local metaA = methods.isInstance(a) and methods.getMeta(a, name)
        local metaB = methods.isInstance(b) and methods.getMeta(b, name)
        if metaA then return methods.safeReturn(metaA, a, b)
        elseif metaB then return methods.safeReturn(metaB, a, b)
        elseif name == "equals" then return refs[a] and refs[b] and refs[a] == refs[b]
        else error(("Operator %q not implemented"):format(name), 2) end
    end
end

function methods.construct(cls, ...)
    if cls ~= module and not methods.isClass(cls) then
        error(("Invalid class (got: %s)"):format(tostring(cls)), 2)
    end
    local obj = {}
    local id = tostring(obj):match("table: (.+)")
    local ref = {
        type    = "instance",
        id      = id,
        class   = cls ~= module and cls or nil,
        super   = cls ~= module and refs[cls].super or nil,
        getters = {},
        setters = {},
        meta    = {}
    }
    ids[id] = obj
    refs[obj] = ref
    setmetatable(obj, objectMt)
    local init = methods.getMeta(obj, "init")
    if init then
        local result = methods.safeInvoke(init, obj, ...)
        if methods.instanceOf(result, cls) then return result end
    end
    return obj
end

local classMt = {
    __index    = methods.get,
    __newindex = methods.set,
    __metatable = {},
    __tostring  = function(class)
        local ref = refs[class]
        return ("class: %s"):format(ref.name or ref.id)
    end,
    __call = methods.construct
}

function methods.class(super, name)
    if super == module then super = nil end
    if super and not methods.isClass(super) then
        error(("Superclass must be a class (got: %s)"):format(tostring(super)), 2)
    end
    if name and type(name) ~= "string" then
        error(("Class name must be a string (got: %s)"):format(type(name)), 2)
    end
    local cls = {}
    if name then
        if named[name] then
            error(("A class named %q already exists"):format(name), 2)
        end
        named[name] = cls
    end
    local id = tostring(cls):match("table: (.+)")
    local ref = {
        type    = "class",
        id      = id,
        name    = name,
        super   = super,
        getters = {},
        setters = {},
        meta    = {}
    }
    ids[id] = cls
    refs[cls] = ref
    setmetatable(cls, classMt)
    local setup = methods.getMeta(cls, "setup")
    if setup then methods.safeInvoke(setup, cls) end
    return cls
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

local function nextInstance(curr)
    local obj, ref = next(refs, curr)
    while obj and ref.type ~= "instance" do
        obj, ref = next(refs, obj)
    end
    return obj
end
function methods.instances()
    return methods.iterate(nextInstance(nil), nextInstance)
end

local function nextOf(curr)
    local obj = nextInstance(curr)
    while obj and not methods.instanceOf(obj, cls) do
        obj = nextInstance(obj)
    end
    return obj
end
function methods.instancesOf(cls)
    return methods.iterate(nextOf(nil), nextOf)
end

local function nextDirect(curr)
    local obj = nextInstance(curr)
    while obj and refs[obj].class ~= cls do
        obj = nextInstance(obj)
    end
    return obj
end
function methods.directInstancesOf(cls)
    return methods.iterate(nextDirect(nil), nextDirect)
end

local PATH = ...
local submodules = {
    array   = false,
    vector  = false,
    object  = false,
    element = false
}

refs[module] = {}

return setmetatable(module, {
    __index = function(t, k)
        if submodules[k] then
            return submodules[k]
        elseif submodules[k] == false then
            submodules[k] = require(PATH .. k)
            return submodules[k]
        else
            return methods[k] or named[k]
        end
    end,
    __newindex = function() end,
    __metatable = {},
    __tostring  = function() return "<FLOOF module>" end,
    __call      = methods.class
})
