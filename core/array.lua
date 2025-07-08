local arrays = setmetatable({}, {__mode = "k"})
local function isArray(t)
    return arrays[t] or false
end
local ntostr = function(n) return tostring(n):match("^(.-%..-)0000.*$") or tostring(n) end -- number string truncation (get rid of excessive decimals)
local arrayMethods = {
    push = function(t, v, i)
        if not isArray(t) then return end
        if type(i) ~= "number" or i ~= math.floor(i) then return end
        i = i or 1
        if i <= 0 then
            i = #t + i + 1
        end
        if i <= 0 or i > #t + 1 then return end
        table.insert(t, i, v)
    end,
    pop = function(t, i)
        if not isArray(t) then return end
        if type(i) ~= "number" or i ~= math.floor(i) then return end
        i = i or 1
        if i <= 0 then
            i = #t + i + 1
        end
        if i <= 0 or i > #t then return end
        return table.remove(t, i)
    end,
    append = function(t, v)
        if not isArray(t) then return end
        table.insert(t, v)
    end,
    find = function(t, v)
        if not isArray(t) then return end
        for i = 1, #t do
            if t[i] == v then
                return i
            end
        end
    end,
    remove = function(t, v)
        if not isArray(t) then return end
        for i = #t, 1, -1 do
            if t[i] == v then
                t:pop(i)
            end
        end
    end
}
local arrayMt
local function newArray(...)
    local array = setmetatable({}, arrayMt)
    arrays[array] = true
    for i, v in ipairs{...} do
        array:append(v)
    end
    return array
end
arrayMt = {
    __index = function(t, k)
        if type(k) == "number" and k == math.floor(k) then
            if k <= 0 then
                k = #t + k + 1
            end
            return rawget(t, k)
        else
            return arrayMethods[k]
        end
    end,
    __newindex = function(t, k, v)
        if type(k) == "number" and k == math.floor(k) then
            if k <= 0 then
                k = #t + k + 1
            end
            if k <= 0 or k > #t + 1 then return end
            rawset(t, k, v)
        end
    end,
    __tostring = function(t)
        if #t == 0 then return "[]" end
        local s = "["..ntostr(t[1])
        for i = 2, #t do
            s = s .. (", %s"):format(ntostr(t[i]))
        end
        return s.."]"
    end,
    __concat = function(a, b)
        if not isArray(a) or not isArray(b) then return end
        local array = newArray()
        for i, v in ipairs(a) do
            table.insert(array, v)
        end
        for i, v in ipairs(b) do
            table.insert(array, v)
        end
        return array
    end,
    __metatable = {}
}

return {
    is = isArray,
    new = newArray
} 