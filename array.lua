-- FLOOF: Fast Lua Object-Oriented Framework
-- Copyright (c) 2026 Matus Kordos

local PATH = (...):match("^(.*%.).-$") or ""
local floof = require(PATH)

local Array = floof:class("Array")
Array.Proxy = Array:class("Array.Proxy")

local proxySrc = setmetatable({}, {__mode = "k"})

local length = setmetatable({}, {__mode = "k"})
local function len(self) return length[self] or proxySrc[self] and length[proxySrc[self]] or 0 end

function Array:__init(...)
    if not floof.instanceOf(self, Array) then
        error(("Invalid caller: Array expected, got %s"):format(floof.typeOf(self)), 2)
    end
    length[self] = 0
    for i, v in ipairs{...} do
        self:append(v)
    end
end

function Array.Proxy:__init(array)
    if not floof.instanceOf(self, Array) then
        error(("Invalid caller: Array expected, got %s"):format(floof.typeOf(self)), 2)
    end
    if not length[array] then
        error(("Invalid source: mutable Array expected, got %s"):format(floof.typeOf(array)), 2)
    end
    proxySrc[self] = array
end

function Array.range(start, stop, step)
    if type(start) == "number" and stop == nil and step == nil then
        start, stop, step = 1, start, 1
    end
    if type(start) == "number" and type(stop) == "number" and step == nil then
        step = stop < start and -1 or 1
    end
    if type(start) ~= "number" then
        error(("Invalid start: number expected, got %s"):format(floof.typeOf(start)), 2)
    end
    if type(stop) ~= "number" then
        error(("Invalid stop: number expected, got %s"):format(floof.typeOf(stop)), 2)
    end
    if type(step) ~= "number" then
        error(("Invalid step: number expected, got %s"):format(floof.typeOf(step)), 2)
    elseif step == 0 then
        error("Step must be non-zero", 2)
    end
    local result = Array()
    for i = start, stop, step do
        result:append(i)
    end
    return result
end

local function single_iter(array, i)
    i = i + 1
    if i == 0 or i > len(array) then return end
    return i, array[i]
end
local function multi_iter(arrays, i)
    i = i + 1
    if i == 0 then return end
    local v = Array()
    for _, array in ipairs(arrays) do
        if i > len(array) then return end
        v:append(array[i])
    end
    return i, v:unpack()
end
function Array.iterate(...)
    local arrays = {...}
    if #arrays == 0 then error("No arrays provided", 2) end
    for i, v in ipairs(arrays) do
        if not floof.instanceOf(v, Array) then
            error(("All arguments must be arrays (got: %s)"):format(floof.getClass(v) and floof.getClass(v).name or type(v)), 2)
        end
        arrays[i] = v:copy()
    end
    if #arrays == 1 then
        return single_iter, arrays[1], 0
    else
        return multi_iter, arrays, 0
    end
end
function Array.backtrack(...)
    local arrays = {...}
    if #arrays == 0 then error("No arrays provided", 2) end
    local l = math.huge
    for i, v in ipairs(arrays) do
        if not floof.instanceOf(v, Array) then
            error(("All arguments must be arrays (got: %s)"):format(floof.getClass(v) and floof.getClass(v).name or type(v)), 2)
        end
        arrays[i] = v:copy()
        if len(v) < l then
            l = len(v)
        end
    end
    if #arrays == 1 then
        return single_iter, arrays[1], -l - 1
    else
        return multi_iter, arrays, -l - 1
    end
end

function Array:push(v, i)
    if not length[self] then
        error(("Invalid caller: mutable Array expected, got %s"):format(floof.typeOf(self)), 2)
    end
    i = i or 1
    if type(i) ~= "number" then
        error(("Invalid index: integer expected, got %s"):format(floof.typeOf(i)), 2)
    elseif i ~= math.floor(i) then
        error(("Invalid index (%s): integer expected"):format(tostring(i)), 2)
    end
    if i <= 0 then
        i = length[self] + i + 1
    end
    i = math.max(1, math.min(i, length[self] + 1))
    length[self] = length[self] + 1
    table.insert(self, i, v)
    return self
end

function Array:pop(i)
    if not length[self] then
        error(("Invalid caller: mutable Array expected, got %s"):format(floof.typeOf(self)), 2)
    end
    i = i or 1
    if type(i) ~= "number" then
        error(("Invalid index: integer expected, got %s"):format(floof.typeOf(i)), 2)
    elseif i ~= math.floor(i) then
        error(("Invalid index (%s): integer expected"):format(tostring(i)), 2)
    end
    if i <= 0 then
        i = length[self] + i + 1
    end
    i = math.max(1, math.min(i, length[self]))
    length[self] = math.max(length[self] - 1, 0)
    return table.remove(self, i)
end

function Array:append(v)
    if not length[self] then
        error(("Invalid caller: mutable Array expected, got %s"):format(floof.typeOf(self)), 2)
    end
    length[self] = length[self] + 1
    table.insert(self, v)
    return self
end

function Array:find(v)
    if not floof.instanceOf(self, Array) then
        error(("Invalid caller: Array expected, got %s"):format(floof.typeOf(self)), 2)
    end
    for i, u in self:iterate() do
        if u == v then
            return i
        end
    end
end

function Array:remove(v)
    if not length[self] then
        error(("Invalid caller: mutable Array expected, got %s"):format(floof.typeOf(self)), 2)
    end
    for i, u in self:iterate() do
        if u == v then
            self:pop(i)
            break
        end
    end
    return self
end

function Array:removeAll(v)
    if not length[self] then
        error(("Invalid caller: mutable Array expected, got %s"):format(floof.typeOf(self)), 2)
    end
    for i, u in self:iterate() do
        if u == v then
            self:pop(i)
        end
    end
    return self
end

function Array:clear()
    if not length[self] then
        error(("Invalid caller: mutable Array expected, got %s"):format(floof.typeOf(self)), 2)
    end
    for i = 1, length[self] do
        self[i] = nil
    end
    length[self] = 0
    return self
end

function Array:unpack()
    if not floof.instanceOf(self, Array) then
        error(("Invalid caller: Array expected, got %s"):format(floof.typeOf(self)), 2)
    end
    if proxySrc[self] then
        return unpack(proxySrc[self])
    else
        return unpack(self)
    end
end

function Array:copy()
    if not floof.instanceOf(self, Array) then
        error(("Invalid caller: Array expected, got %s"):format(floof.typeOf(self)), 2)
    end
    local array = Array()
    for i = 1, len(self) do array:append(self[i]) end
    return array
end

function Array:slice(start, stop, step)
    if start == nil then
        return Array()
    end
    if stop == nil then
        stop = start
        start = 1
    end
    if step == nil then
        step = 1
    end
    if type(start) ~= "number" or type(stop) ~= "number" or type(step) ~= "number" then
        error(("Start, stop, and step must be numbers (got: %s, %s, %s)"):format(type(start), type(stop), type(step)), 2)
    end
    if step == 0 then
        error("Step cannot be 0", 2)
    end
    local result = Array()
    for i = start, stop, step do
        result:append(self[i])
    end
    return result
end

function Array.zip(...)
    local arrays = {...}
    if #arrays == 0 then error("No arrays provided", 2) end
    local l = math.huge
    for i, v in ipairs(arrays) do
        if not floof.instanceOf(v, Array) then
            error(("All arguments must be arrays (got: %s)"):format(floof.getClass(v) and floof.getClass(v).name or type(v)), 2)
        end
        if len(v) < l then
            l = len(v)
        end
    end
    local result = Array()
    for i = 1, l do
        local v = Array()
        for _, array in ipairs(arrays) do
            if i > len(array) then break end
            v:append(array[i])
        end
        result:append(v)
    end
    return result
end

function Array:min(func)
    if not floof.instanceOf(self, Array) then
        error(("Invalid caller: Array expected, got %s"):format(floof.typeOf(self)), 2)
    end
    if not floof.isCallable(func) then
        error(("Invalid comparator: callable expected, got %s"):format(floof.typeOf(func)), 2)
    end
    local min
    for i, v in self:iterate() do
        if not func and type(v) ~= "number" then
            error(("Invalid value encountered: number expected, got %s"):format(floof.typeOf(v)))
        end
        if min == nil or func and floof.safeInvoke(func, v, min) or v < min then
            min = v
        end
    end
    return min
end

function Array:max(func)
    if not floof.instanceOf(self, Array) then
        error(("Invalid caller: Array expected, got %s"):format(floof.typeOf(self)), 2)
    end
    if not floof.isCallable(func) then
        error(("Invalid comparator: callable expected, got %s"):format(floof.typeOf(func)), 2)
    end
    local max
    for i, v in self:iterate() do
        if not func and type(v) ~= "number" then
            error(("Invalid value encountered: number expected, got %s"):format(floof.typeOf(v)))
        end
        if max == nil or func and floof.safeInvoke(func, v, max) or v > max then
            max = v
        end
    end
    return max
end

function Array:reduce(func, value)
    if not floof.instanceOf(self, Array) then
        error(("Invalid caller: Array expected, got %s"):format(floof.getClass(v) and floof.getClass(v).name or type(v)), 3)
    end
    if not floof.isCallable(func) then
        error(("Invalid merger: callable expected, got %s"):format(floof.typeOf(func)), 2)
    end
    for i, v in self:iterate() do
        if value == nil then value = v else
            value = floof.safeInvoke(func, value, v, i)
        end
    end
    return value
end

function Array:search(func)
    if not floof.instanceOf(self, Array) then
        error(("Invalid caller: Array expected, got %s"):format(floof.getClass(v) and floof.getClass(v).name or type(v)), 3)
    end
    if not floof.isCallable(func) then
        error(("Invalid condition: callable expected, got %s"):format(floof.typeOf(func)), 2)
    end
    for i, v in self:iterate() do
        if floof.safeInvoke(func, v, i) then
            return v, i
        end
    end
end

function Array:foreach(func)
    if not floof.instanceOf(self, Array) then
        error(("Invalid caller: Array expected, got %s"):format(floof.typeOf(self)), 2)
    end
    if not floof.isCallable(func) then
        error(("Invalid action: callable expected, got %s"):format(floof.typeOf(func)), 2)
    end
    for i, v in self:iterate() do
        if floof.safeInvoke(func, v, i) == false then
            break
        end
    end
    return self
end

function Array:sort(func)
    if not length[self] then
        error(("Invalid caller: mutable Array expected, got %s"):format(floof.typeOf(self)), 2)
    end
    if not floof.isCallable(func) then
        error(("Invalid comparator: callable expected, got %s"):format(floof.typeOf(func)), 2)
    end
    floof.safeInvoke(table.sort, self, func)
    return self
end

function Array:sorted(func)
    if not floof.instanceOf(self, Array) then
        error(("Invalid caller: Array expected, got %s"):format(floof.typeOf(self)), 2)
    end
    if not floof.isCallable(func) then
        error(("Invalid comparator: callable expected, got %s"):format(floof.typeOf(func)), 2)
    end
    local r = Array()
    for i, v in self:iterate() do
        local inserted = false
        for j, w in r:iterate() do
            if floof.safeInvoke(func, v, w) then
                r:push(v, j)
                inserted = true
                break
            end
        end
        if not inserted then
            r:append(v)
        end
    end
    return r
end

function Array:reverse()
    if not length[self] then
        error(("Invalid caller: mutable Array expected, got %s"):format(floof.typeOf(self)), 2)
    end
    for i = 1, math.floor(length[self] / 2) do
        self[i], self[length[self] - i + 1] = self[length[self] - i + 1], self[i]
    end
    return self
end

function Array:reversed()
    if not floof.instanceOf(self, Array) then
        error(("Invalid caller: Array expected, got %s"):format(floof.typeOf(self)), 2)
    end
    local r = Array()
    for i, v in self:backtrack() do
        r:append(v)
    end
    return r
end

function Array:filter(func)
    if not length[self] then
        error(("Invalid caller: mutable Array expected, got %s"):format(floof.typeOf(self)), 2)
    end
    if not floof.isCallable(func) then
        error(("Invalid condition: callable expected, got %s"):format(floof.typeOf(func)), 2)
    end
    for i, v in self:iterate() do
        if not floof.safeInvoke(func, v, i) then
            self:pop(i)
        end
    end
    return self
end

function Array:filtered(func)
    if not floof.instanceOf(self, Array) then
        error(("Invalid caller: Array expected, got %s"):format(floof.typeOf(self)), 2)
    end
    if not floof.isCallable(func) then
        error(("Invalid condition: callable expected, got %s"):format(floof.typeOf(func)), 2)
    end
    local f = Array()
    for i, v in self:iterate() do
        if floof.safeInvoke(func, v, i) then
            f:append(v)
        end
    end
    return f
end

function Array:map(func, results)
    if not length[self] then
        error(("Invalid caller: mutable Array expected, got %s"):format(floof.typeOf(self)), 2)
    end
    if not floof.isCallable(func) then
        error(("Invalid converter: callable expected, got %s"):format(floof.typeOf(func)), 2)
    end
    if results == nil then results = 1 end
    if type(results) ~= "number" then
        error(("Invalid result count: number expected, got %s"):format(floof.typeOf(results)), 2)
    elseif results < 0 or results ~= math.floor(results) then
        error(("Invalid result count (%s): non-negative integer expected"):format(tostring(results)), 2)
    end
    for i, v in self:iterate() do
        self:pop(i)
        if results == 1 then
            self:push(floof.safeInvoke(func, v, i), i)
        else
            local res = Array(floof.safeInvoke(func, v, i))
            if results == 0 then
                for j, w in res:iterate() do
                    self:push(w, i + j - 1)
                end
            else
                for j = 1, results do
                    self:push(res[j], i + j - 1)
                end
            end
        end
    end
    return self
end

function Array:mapped(func, results)
    if not floof.instanceOf(self, Array) then
        error(("Invalid caller: Array expected, got %s"):format(floof.typeOf(self)), 2)
    end
    if not floof.isCallable(func) then
        error(("Invalid converter: callable expected, got %s"):format(floof.typeOf(func)), 2)
    end
    if results == nil then results = 1 end
    if type(results) ~= "number" then
        error(("Invalid result count: number expected, got %s"):format(floof.typeOf(results)), 2)
    elseif results < 0 or results ~= math.floor(results) then
        error(("Invalid result count (%s): non-negative integer expected"):format(tostring(results)), 2)
    end
    local m = Array()
    for i, v in self:iterate() do
        if results == 1 then
            m:append(floof.safeInvoke(func, v, i))
        else
            local res = Array(floof.safeInvoke(func, v, i))
            if results == 0 then
                for j, w in res:iterate() do
                    m:append(w)
                end
            else
                for j = 1, results do
                    m:append(res[j])
                end
            end
        end
    end
    return m
end

function Array:__get_length()
    if not floof.instanceOf(self, Array) then
        error(("Invalid caller: Array expected, got %s"):format(floof.typeOf(self)), 2)
    end
    return len(self)
end

function Array:__get_empty()
    if not floof.instanceOf(self, Array) then
        error(("Invalid caller: Array expected, got %s"):format(floof.typeOf(self)), 2)
    end
    for i, v in self:iterate() do
        if v ~= nil then return false end
    end
    return true
end

function Array:__get_full()
    if not floof.instanceOf(self, Array) then
        error(("Invalid caller: Array expected, got %s"):format(floof.typeOf(self)), 2)
    end
    for i, v in self:iterate() do
        if v == nil then return false end
    end
    return true
end

function Array.Proxy:__get_source() return proxySrc[self] end
function Array.Proxy:__set_source(v)
    if not floof.instanceOf(v, Array) then
        error(("Invalid value: Array expected, got %s"):format(floof.typeOf(v)), 2)
    end
    if proxySrc[v] then
        proxySrc[self] = proxySrc[v]
    else
        proxySrc[self] = v
    end
end

function Array:__get(k)
    if floof.instanceOf(self, Array) then
        if type(k) == "number" and k == math.floor(k) then
            if k <= 0 then
                k = len(self) + k + 1
            end
            return proxySrc[self] and rawget(proxySrc[self], k) or rawget(self, k)
        end
    end
end

function Array:__set(k, v)
    if floof.instanceOf(self, Array) then
        if type(k) == "number" and k == math.floor(k) then
            if proxySrc[self] then error(("%s is immutable"):format(floof.typeOf(self)), 2) end
            if k <= 0 then
                k = length[self] + k + 1
            end
            if k <= 0 or k > length[self] then error(("Invalid index (%d): out of range"):format(k), 2) end
        end
    end
    rawset(self, k, v)
end

local str = function(v)
    local s = tostring(v):gsub("\n", "\\n")
    return type(v) == "string" and ('"%s"'):format(s) or s
end
function Array:__tostring()
    if not floof.instanceOf(self, Array) then
        error(("Invalid caller: Array expected, got %s"):format(floof.typeOf(self)), 2)
    end
    if len(self) == 0 then return "[]" end
    local s = "["
    for i, v in self:iterate() do
        if i > 1 then s = s .. ", " end
        s = s .. str(v)
    end
    return s .. "]"
end

function Array:__concat(other)
    if not floof.instanceOf(self, Array) then
        error(("Invalid operand #1: Array expected, got %s"):format(floof.typeOf(self)), 2)
    end
    if not floof.instanceOf(other, Array) then
        error(("Invalid operand #2: Array expected, got %s"):format(floof.typeOf(other)), 2)
    end
    local result = self:copy()
    for i, e in ipairs(other) do
        result:append(e)
    end
    return result
end

function Array:__equals(other)
    if not floof.instanceOf(self, Array) then
        error(("Invalid operand #1: Array expected, got %s"):format(floof.typeOf(self)), 2)
    end
    if not floof.instanceOf(other, Array) then
        error(("Invalid operand #2: Array expected, got %s"):format(floof.typeOf(other)), 2)
    end
    if len(self) ~= len(other) then return false end
    for i = 1, len(self) do
        if self[i] ~= other[i] then return false end
    end
    return true
end

function Array:__invert()
    if not floof.instanceOf(self, Array) then
        error(("Invalid value: Array expected, got %s"):format(floof.typeOf(self)), 2)
    end
    local result = Array()
    for i, v in ipairs(self) do
        if floof.supportsArithmetic(v, "invert") then
            result:append(-v)
        else
            error(("Invalid value encountered: number or invertible expected, got %s"):format(floof.typeOf(v)), 2)
        end
    end
    return result
end

local function arrayOperation(f, name)
    return function(self, other)
        local result = Array()
        if floof.instanceOf(self, Array) and floof.instanceOf(other, Array) then
            for i, u, v in Array.iterate(self, other) do
                local s, r = pcall(f, u, v)
                if not s then
                    error(("Failed to perform %s on %s and %s"):format(name, floof.typeOf(u), floof.typeOf(v)), 2)
                end
                result:append(r)
            end
        elseif floof.instanceOf(self, Array) then
            for i, v in self:iterate() do
                local s, r = pcall(f, v, other)
                if not s then
                    error(("Failed to perform %s on %s and %s"):format(name, floof.typeOf(v), floof.typeOf(other)), 2)
                end
                result:append(r)
            end
        elseif floof.instanceOf(other, Array) then
            for i, v in other:iterate() do
                local s, r = pcall(f, self, v)
                if not s then
                    error(("Failed to perform %s on %s and %s"):format(name, floof.typeOf(self), floof.typeOf(v)), 2)
                end
                result:append(r)
            end
        end
        return result
    end
end

Array:meta("add",      arrayOperation(function(a, b) return a + b end, "addition"      ))
Array:meta("subtract", arrayOperation(function(a, b) return a - b end, "subtraction"   ))
Array:meta("multiply", arrayOperation(function(a, b) return a * b end, "multiplication"))
Array:meta("divide",   arrayOperation(function(a, b) return a / b end, "division"      ))
Array:meta("power",    arrayOperation(function(a, b) return a ^ b end, "exponentiation"))
Array:meta("modulo",   arrayOperation(function(a, b) return a % b end, "modulo"        ))

return Array