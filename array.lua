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
    if Array:isClassOf(v) then
        for i, e in ipairs(v) do
            self:append(e)
        end
    else
        self._length = self._length + 1
        table.insert(self, v)
    end
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

function Array:clone()
    local array = Array()
    for i, v in ipairs(self) do
        array:append(v)
    end
    return array
end

Array:getter("length", function(self)   
    return self._length
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
    if not class.isInstanceOf(other, Array) then return end
    return self:clone():append(other)
end)

return Array