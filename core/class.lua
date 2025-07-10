local _PATH = (...):match("(.-)[^%.]+$")
local array = require(_PATH .. ".array")

-- Class identification and management
local classes = setmetatable({}, {__mode = "k"})
local named = setmetatable({}, {__mode = "v"})



local function isClass(o, c)
    return o and classes[o] ~= nil and (not c or o == c or isClass(classes[o].super, c))
end

-- Index traversal for mixins
local function _index(indexes, t, k, visited)
    for i, index in ipairs(indexes) do
        local v
        if type(index) == "table" then
            v = index[k]
        elseif type(index) == "function" then
            local s, e = pcall(index, t, k)
            if not s then 
                error(("Error while trying to access field %s (layer %d, %s): %s"):format(
                    type(k) == "string" and '"'..k..'"' or tostring(k), i, tostring(index), e), 3) 
            else 
                v = e 
            end
        end
        if v ~= nil then return v end
    end
end

-- Class metatable
local classMt = {
    __index = function(c, k)
        local ref = c and classes[c]
        if not ref then return end
        
        return k == "name" and ref.name or
               k == "super" and ref.super or
               k == "check" and ref.check or
               k == "indexes" and ref.indexes or
               ref.callbacks[k] or
               _index(ref.indexes, c, k) or
               ref.super and ref.super[k]
    end,
    
    __newindex = function(c, k, v)
        local ref = c and classes[c]
        if not ref then return end
        
        if k == "name" then
            if type(v) == "string" then
                if named[v] then
                    error(("A class named %q already exists"):format(v), 2)
                end
                if named[ref.name] then named[ref.name] = nil end
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
        elseif k == "callbacks" then
            -- Handle callback assignments
            if v == nil then
                ref.callbacks[k] = nil
            elseif type(v) == "boolean" then
                ref.callbacks[k] = function() return v end
            elseif type(v) == "function" then
                ref.callbacks[k] = v
            else
                error(("Cannot assign non-function value to %q (got: %s (%s))"):format(k, tostring(v), type(v)), 2)
            end
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
        -- Create a new object with this class (lazy load to avoid circular dependency)
        if not classMt.objectModule then
            classMt.objectModule = require(_PATH .. ".object")
        end
        return classMt.objectModule.new({}, c, ...)
    end
}

-- Class methods
local classMethods = {
    index = function(c, ...)
        if isClass(c) then
            for k, i in ipairs{...} do
                c.indexes:push(i, k)
            end
        end
    end
}

-- Class constructor
local function newClass(name, super, blueprint)
    if name and type(name) ~= "string" then
        super, blueprint, name = name, super
    end
    if super and not isClass(super) then
        blueprint, super = super
    end
    
    blueprint = type(blueprint) == "table" and blueprint or {}
    
    if not pcall(setmetatable, blueprint, nil) then
        error("Classes with custom metatables are not supported. If you want to implement an indexing metatable/metamethod, use the 'indexes' field", 2)
    end
    
    name = name or tostring(blueprint):match("table: (.+)") or tostring(blueprint)
    
    if name then
        if named[name] then
            error(("A class named %q already exists"):format(name), 2)
        else
            named[name] = blueprint
        end
    end
    
    local ref = {
        name = name,
        super = super,
        check = nil,
        indexes = array.new(),
        callbacks = {}
    }
    
    classes[blueprint] = ref
    
    -- Copy data before transforming
    local data = {}
    for k, v in pairs(blueprint) do 
        data[k], blueprint[k] = v 
    end
    
    setmetatable(blueprint, classMt)
    
    -- Copy data back
    for k, v in pairs(data) do
        local s, e = pcall(function() rawset(blueprint, k, v) end)
        if not s then error(e, 2) end
    end
    
    return blueprint
end

-- Module interface
local module = {
    is = isClass,
    new = newClass
}

-- Add class methods to module
for k, v in pairs(classMethods) do
    module[k] = v
end

-- Module metatable for named access
return setmetatable(module, {
    __index = function(_, k) 
        return module[k] or named[k] 
    end,
    __newindex = function() end,
    __metatable = {},
    __tostring = function() return "FLOOF class module" end,
    __call = newClass
}) 