local class = require("class")

local ntostr = function(n) 
    return tostring(n):match("^(.-%..-)0000.*$") or tostring(n) 
end

local Array = class("Array")

function Array:init(...)
    self._data = {}
    for i, v in ipairs{...} do
        self:append(v)
    end
end

function Array:push(v, i)
    if type(i) ~= "number" or i ~= math.floor(i) then return end
    i = i or 1
    if i <= 0 then
        i = #self._data + i + 1
    end
    if i <= 0 or i > #self._data + 1 then return end
    table.insert(self._data, i, v)
end

function Array:pop(i)
    if type(i) ~= "number" or i ~= math.floor(i) then return end
    i = i or 1
    if i <= 0 then
        i = #self._data + i + 1
    end
    if i <= 0 or i > #self._data then return end
    return table.remove(self._data, i)
end

function Array:append(v)
    table.insert(self._data, v)
end

function Array:find(v)
    for i = 1, #self._data do
        if self._data[i] == v then
            return i
        end
    end
end

function Array:remove(v)
    for i = #self._data, 1, -1 do
        if self._data[i] == v then
            self:pop(i)
        end
    end
end

function Array:clear()
    self._data = {}
end

function Array:length()
    return #self._data
end

function Array:isEmpty()
    return #self._data == 0
end

Array:meta("get", function(self, k)
    if type(k) == "number" and k == math.floor(k) then
        if k <= 0 then
            k = #self._data + k + 1
        end
        return rawget(self._data, k)
    end
    return nil
end)

Array:meta("set", function(self, k, v)
    if type(k) == "number" and k == math.floor(k) then
        if k <= 0 then
            k = #self._data + k + 1
        end
        if k <= 0 or k > #self._data + 1 then return end
        rawset(self._data, k, v)
    else
        rawset(self, k, v)
    end
end)

Array:meta("tostring", function(self)
    if #self._data == 0 then return "[]" end
    local s = "["..ntostr(self._data[1])
    for i = 2, #self._data do
        s = s .. (", %s"):format(ntostr(self._data[i]))
    end
    return s.."]"
end)

Array:meta("concat", function(self, other)
    if not class.isInstance(other, Array) then return end
    local array = Array()
    for i, v in ipairs(self._data) do
        array:append(v)
    end
    for i, v in ipairs(other._data) do
        array:append(v)
    end
    return array
end)

return Array