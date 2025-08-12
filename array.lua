local class = require("class")

local ntostr = function(n) 
    return tostring(n):match("^(.-%..-)0000.*$") or tostring(n) 
end

local Array = class("Array")

function Array:init(...)
    self._length = 0
    for i, v in ipairs{...} do
        self:append(v)
    end
end

function Array:push(v, i)
    i = i or 1
    if type(i) ~= "number" or i ~= math.floor(i) then return end
    if i <= 0 then
        i = self.length + i + 1
    end
    if i <= 0 or i > self.length + 1 then return end
    self._length = self._length + 1
    table.insert(self, i, v)
    return self
end

function Array:pop(i)
    i = i or 1
    if type(i) ~= "number" or i ~= math.floor(i) then return end
    if i <= 0 then
        i = self.length + i + 1
    end
    if i <= 0 or i > self.length then return end
    self._length = self._length - 1
    return table.remove(self, i)
end

function Array:append(v)
    self._length = self._length + 1
    table.insert(self, v)
    return self
end

function Array:find(v)
    for i = 1, self.length do
        if self[i] == v then
            return i
        end
    end
end

function Array:remove(v)
    for i = self.length, 1, -1 do
        if self[i] == v then
            self:pop(i)
        end
    end
    return self
end

function Array:clear()
    for i = 1, self.length do
        self[i] = nil
    end
    self._length = 0
    return self
end

function Array:unpack()
    return table.unpack(self)
end

function Array:foreach(func)
    for i, v in ipairs(self) do
        if func(v, i, self) == false then
            break
        end
    end
    return self
end

function Array:copy()
    local array = Array()
    for i, v in ipairs(self) do
        array:append(v)
    end
    return array
end

local function stateless_iter(arrays, i)
    i = i + 1
    local v = Array()
    for _, array in ipairs(arrays) do
        if i > array.length then return end
        v:append(array[i])
    end
    return i, v:unpack()
end
function Array:iterate(...)
    local arrays = Array(self, ...)
    arrays:foreach(function(v)
        if not Array:isClassOf(v) then
            error(("All arguments must be arrays (got: %s)"):format(class.getClass(v) and class.getClass(v).name or type(v)), 3)
        end
    end)
    
    return stateless_iter, arrays, 0
end

function Array:zip(...)
    local arrays = Array(self, ...)
    arrays:foreach(function(v)
        if not Array:isClassOf(v) then
            error(("All arguments must be arrays (got: %s)"):format(class.getClass(v) and class.getClass(v).name or type(v)), 3)
        end
    end)
    
    local result = Array()
    local i = 0
    while true do
        local v = Array()
        for _, array in ipairs(arrays) do
            if i > array.length then break end
            v:append(array[i])
        end
        result:append(v)
        i = i + 1
    end
    return result
end

function Array:sort(comparator)
    table.sort(self, comparator)
    return self
end

function Array:sorted(comparator)
    return self:copy():sort(comparator)
end

function Array:reverse()
    for i = 1, math.floor(self.length / 2) do
        self[i], self[self.length - i + 1] = self[self.length - i + 1], self[i]
    end
    return self
end

function Array:reversed()
    return self:copy():reverse()
end

function Array:map(func)
    return self:foreach(function(v, i, self)
        self[i] = func(v, i, self)
    end)
end

function Array:mapped(func)
    return self:copy():map(func)
end

function Array:filter(func)
    for i = self.length, 1, -1 do
        if not func(self[i], i, self) then
            self:pop(i)
        end
    end
    return self
end

function Array:filtered(func)
    return self:copy():filter(func)
end

function Array:reduce(func, value)
    local start = 1
    if value == nil then
        value = self[1]
        start = 2
    end
    for i = start, self.length do
        local v = self[i]
        value = func(value, v, i, self)
    end
    return value
end

function Array:search(func)
    for i, v in ipairs(self) do
        if func(v, i, self) then
            return v, i
        end
    end
end

function Array:min()
    local min = math.huge
    for i, v in ipairs(self) do
        if type(v) ~= "number" then
            error(("Array must not contain non-number values (got: %s)"):format(class.getClass(v) and class.getClass(v).name or type(v)), 2)
        end
        if v < min then
            min = v
        end
    end
    return min
end

function Array:max()
    local max = -math.huge
    for i, v in ipairs(self) do
        if type(v) ~= "number" then
            error(("Array must not contain non-number values (got: %s)"):format(class.getClass(v) and class.getClass(v).name or type(v)), 2)
        end
        if v > max then
            max = v
        end
    end
    return max
end

function Array:sum()
    local sum = 0
    for i, v in ipairs(self) do
        if type(v) ~= "number" then
            error(("Array must not contain non-number values (got: %s)"):format(class.getClass(v) and class.getClass(v).name or type(v)), 2)
        end
        sum = sum + v
    end
    return sum
end

function Array:average()
    local sum = 0
    for i, v in ipairs(self) do
        if type(v) ~= "number" then
            error(("Array must not contain non-number values (got: %s)"):format(class.getClass(v) and class.getClass(v).name or type(v)), 2)
        end
        sum = sum + v
    end
    return sum / self.length
end

function Array:range(start, stop, step)
    if not stop then
        stop = start
        start = 1
    end
    if not step then
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

Array:getter("length", function(self)   
    return self._length
end)

Array:getter("empty", function(self)
    for i, v in self:iterate() do
        if v ~= nil then return false end
    end
    return true
end)

Array:getter("full", function(self)
    for i, v in self:iterate() do
        if v == nil then return false end
    end
    return true
end)

Array:meta("get", function(self, k)
    if type(k) == "number" and k == math.floor(k) then
        if k <= 0 then
            k = self.length + k + 1
        end
        return rawget(self, k)
    end
    return nil
end)

Array:meta("set", function(self, k, v)
    if type(k) == "number" and k == math.floor(k) then
        if k <= 0 then
            k = self.length + k + 1
        end
        if k <= 0 or k > self.length then return end
        rawset(self, k, v)
    else
        rawset(self, k, v)
    end
end)

Array:meta("tostring", function(self)
    if self.length == 0 then return "[]" end
    local s = "[" .. ntostr(self[1])
    for i = 2, self.length do
        s = s .. ", " .. ntostr(self[i])
    end
    return s .. "]"
end)

Array:meta("concat", function(self, other)
    if not Array:isClassOf(other) then return end
    local result = self:copy()
    for i, e in ipairs(other) do
        result:append(e)
    end
    return result
end)

Array:meta("equals", function(self, other)
    if self.length ~= other.length then return false end
    for i = 1, self.length do
        if self[i] ~= other[i] then return false end
    end
    return true
end)

Array:meta("minus", function(self)
    local result = Array()
    for i, v in ipairs(self) do
        if type(v) == "number" or (class.isInstance(v) and v.__minus) then
            result:append(-v)
        else
            error(("Failed to invert %s"):format(
                class.getClass(v) and class.getClass(v).name or type(v) == "string" and '"'..v ..'"' or tostring(v)
            ), 2)
        end
    end
    return result
end)

local function arrayOperation(f, name)
    return function(self, other)
        if Array:isClassOf(self) and Array:isClassOf(other) then
            local result = Array()
            for i = 1, math.min(self.length, other.length) do -- max for nil padding, min for truncation
                if self[i] ~= nil and other[i] == nil then
                    result:append(self[i])
                elseif self[i] == nil and other[i] ~= nil then
                    result:append(other[i])
                else
                    local s, r = pcall(f, self[i], other[i])
                    if not s then error(("Failed to perform %s on %s and %s"):format(
                        name,
                        class.getClass(self[i] ) and class.getClass(self[i] ).name or type(self[i] ),
                        class.getClass(other[i]) and class.getClass(other[i]).name or type(other[i])
                    ), 2) end
                    result:append(r)
                end
            end
            return result
        elseif Array:isClassOf(self) then
            local result = Array()
            for i, v in ipairs(self) do
                local s, r = pcall(f, v, other)
                if not s then error(("Failed to perform %s on %s and %s"):format(
                    name,
                    class.getClass(v    ) and class.getClass(v    ).name or type(v    ),
                    class.getClass(other) and class.getClass(other).name or type(other)
                ), 2) end
                result:append(r)
            end
            return result
        elseif Array:isClassOf(other) then
            local result = Array()
            for i, v in ipairs(other) do
                local s, r = pcall(f, self, v)
                if not s then error(("Failed to perform %s on %s and %s"):format(
                    name,
                    class.getClass(self) and class.getClass(self).name or type(self),
                    class.getClass(r   ) and class.getClass(r   ).name or type(r   )
                ), 2) end
                result:append(r)
            end
            return result
        end
    end
end

Array:meta("add",      arrayOperation(function(a, b) return a + b end, "addition"      ))
Array:meta("subtract", arrayOperation(function(a, b) return a - b end, "subtraction"   ))
Array:meta("multiply", arrayOperation(function(a, b) return a * b end, "multiplication"))
Array:meta("divide",   arrayOperation(function(a, b) return a / b end, "division"      ))
Array:meta("power",    arrayOperation(function(a, b) return a ^ b end, "exponentiation"))
Array:meta("modulo",   arrayOperation(function(a, b) return a % b end, "modulo"        ))

return Array