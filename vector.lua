local class = require("class")

-- Aliases
local floor = math.floor
local round = function(n) return floor(n + 0.5) end
local sqrt, abs, sin, cos, asin, acos, atan2 = math.sqrt, math.abs, math.sin, math.cos, math.asin, math.acos, math.atan2
local fstr = string.format
local str = function(v) return type(v) == "string" and '"'..v..'"' or tostring(v) end
local isn, nbetween = function(x) return type(x) == 'number' end, function(x, a, b) return x >= a and x <= b end
local ang = function(x) return math.pi - ((math.pi - x) % (2*math.pi)) end

-- Cache
local reg, repr = {}, {}

local Vector = class("Vector")

function Vector:init(x, y)
    if not (isn(x) and isn(y)) or tostring(x):match("nan") or tostring(y):match("nan") then
        error(fstr("Both vector components must be numbers (got: %s, %s)", str(x), str(y)), 2)
    end

    local k = fstr("(%s, %s)", str(x), str(y))
    if reg[k] then
        return reg[k].instance
    end
    
    local r = {
        x = x,
        y = y,
        sqrLen = x * x + y * y,
        len = sqrt(x * x + y * y),
        atan2 = atan2(y, x),
        instance = self
    }
    if r.len ~= 0 and (x / r.len ~= x or y / r.len ~= y) then
        r.normal = Vector(x / r.len, y / r.len)
    else
        r.normal = self
    end
    reg[k] = r
    repr[self] = k
    
    return self
end

for i, k in ipairs{"x", "y", "sqrLen", "len", "atan2", "normal"} do
    Vector:getter(k, function(self)
        return Vector.is(self) and reg[repr[self]][k]
    end)
end

function Vector.is(v)
    return repr[v] ~= nil
end

function Vector.unpack(v)
    if Vector.is(v) then
        return v.x, v.y
    end
end

function Vector.fromString(s)
    if type(s) == 'string' then
        local x, y = s:match('^%s*[%(%{%[]?(.-)[,;](.-)[%)%}%]]?%s*$')
        if tonumber(x) and tonumber(y) then
            return Vector(tonumber(x), tonumber(y))
        else
            error(fstr("Attempted to convert invalid string to vector (%q)", s), 2)
        end
    else
        error(fstr("Attempted to convert non-string value to vector (%s)", str(s)), 2)
    end
end

function Vector.flattenArray(a)
    if type(a) ~= "table" then return end
    local t = {}
    for i, v in ipairs(a) do
        if not Vector.is(v) then
            error(fstr("Attempted to flatten array with non-vector values (%s)", str(v)), 2)
        end
        table.insert(t, v.x)
        table.insert(t, v.y)
    end
    return t
end

function Vector.dot(a, b)
    if Vector.is(a) and Vector.is(b) then
        return a.x * b.x + a.y * b.y
    else
        error(fstr("Dot product only supported on operands of type: [vector, vector] (got: %s, %s)", str(a), str(b)), 2)
    end
end

function Vector.det(a, b)
    if Vector.is(a) and Vector.is(b) then
        return a.x * b.y - a.y * b.x
    else
        error(fstr("Cross product only supported on operands of type: [vector, vector] (got: %s, %s)", str(a), str(b)), 2)
    end
end

function Vector.angle(a, b)
    if Vector.is(a) and Vector.is(b) then
        return asin(a.normal:dot(b.normal))
    else
        error(fstr("Angle measurement only supported on operands of type: [vector, vector] (got: %s, %s)", str(a), str(b)), 2)
    end
end

function Vector.signedAngle(a, b)
    if Vector.is(a) and Vector.is(b) then
        return asin(a.normal:det(b.normal))
    else
        error(fstr("Signed angle measurement only supported on operands of type: [vector, vector] (got: %s, %s)", str(a), str(b)), 2)
    end
end

function Vector.polar(a, l)
    if isn(a) and (isn(l) or l == nil) then
        return Vector(cos(a), sin(a)) * (l or 1)
    else
        error(fstr("Both direction and length must be numbers (got: %s, %s)", str(a), str(l)), 2)
    end
end

function Vector.rotate(v, a)
    if Vector.is(v) and isn(a) then
        local s, c = sin(a), cos(a)
        return Vector(v.x * c - v.y * s, v.x * s + v.y * c)
    else
        error(fstr("Rotation only supported on operands of type: [vector, number] (got: %s, %s)", str(v), str(a)), 2)
    end
end

function Vector.lerp(a, b, t)
    if Vector.is(a) and Vector.is(b) and isn(t) then
        return a + (b - a) * t
    else
        error(fstr("Linear interpolation only supported on operands of type: [vector, vector, number] (got: %s, %s, %s)", str(a), str(b), str(t)), 2)
    end
end

function Vector.moveTo(a, b, d)
    if Vector.is(a) and Vector.is(b) and isn(d) then
        return a + (b - a).normal * d
    else
        error(fstr("Absolute interpolation only supported on operands of type: [vector, vector, number] (got: %s, %s, %s)", str(a), str(b), str(d)), 2)
    end
end

function Vector.project(a, b)
    if Vector.is(a) and Vector.is(b) then
        if a.len == 0 or b.len == 0 then return Vector.zero end
        return Vector.dot(a, b) / b.sqrLen * b
    else
        error(fstr("Projection only supported on operands of type: [vector, vector] (got: %s, %s)", str(a), str(b)), 2)
    end
end

function Vector.setLen(v, l)
    if Vector.is(v) and isn(l) then
        return v.normal * l
    else
        error(fstr("Length modification only supported on operands of type: [vector, number] (got: %s, %s)", str(v), str(l)), 2)
    end
end

function Vector.maxLen(v, l)
    if Vector.is(v) and isn(l) then
        return v.normal * math.min(v.len, l)
    else
        error(fstr("Length capping only supported on operands of type: [vector, number] (got: %s, %s)", str(v), str(l)), 2)
    end
end

function Vector.minLen(v, l)
    if Vector.is(v) and isn(l) then
        return v.normal * math.max(v.len, l)
    else
        error(fstr("Length flooring only supported on operands of type: [vector, number] (got: %s, %s)", str(v), str(l)), 2)
    end
end

function Vector.clampLen(v, a, b)
    if Vector.is(v) and isn(a) and isn(b) then
        a, b = math.min(a, b), math.max(a, b)
        return v.normal * math.max(a, math.min(b, v.len))
    else
        error(fstr("Length clamping only supported on operands of type: [vector, number, number] (got: %s, %s, %s)", str(v), str(a), str(b)), 2)
    end
end

-- Operator overloading
function Vector:__add(other)
    if Vector.is(self) and Vector.is(other) then
        return Vector(self.x + other.x, self.y + other.y)
    else
        error(fstr("Vector addition only supported on operands of type: [vector, vector] (got: %s, %s)", str(self), str(other)), 2)
    end
end

function Vector:__subtract(other)
    if Vector.is(self) and Vector.is(other) then
        return Vector(self.x - other.x, self.y - other.y)
    else
        error(fstr("Vector subtraction only supported on operands of type: [vector, vector] (got: %s, %s)", str(self), str(other)), 2)
    end
end

function Vector:__multiply(other)
    if Vector.is(self) and Vector.is(other) then
        return Vector(self.x * other.x, self.y * other.y)
    elseif Vector.is(self) and isn(other) then
        return Vector(self.x * other, self.y * other)
    elseif isn(self) and Vector.is(other) then
        return Vector(self * other.x, self * other.y)
    else
        error(fstr("Vector multiplication only supported on operands of type: [vector, vector], [vector, scalar], [scalar, vector] (got: %s, %s)", str(self), str(other)), 2)
    end
end

function Vector:__divide(other)
    if Vector.is(self) and Vector.is(other) then
        return Vector(self.x / other.x, self.y / other.y)
    elseif Vector.is(self) and isn(other) then
        return Vector(self.x / other, self.y / other)
    elseif isn(self) and Vector.is(other) then
        return Vector(self / other.x, self / other.y)
    else
        error(fstr("Vector division only supported on operands of type: [vector, vector], [vector, scalar], [scalar, vector] (got: %s, %s)", str(self), str(other)), 2)
    end
end

function Vector:__power(other)
    if Vector.is(self) and isn(other) then
        return Vector(self.x ^ other, self.y ^ other)
    elseif Vector.is(self) and Vector.is(other) then
        return Vector(self.x ^ other.x, self.y ^ other.y)
    else
        error(fstr("Vector exponentiation only supported on operands of type: [vector, scalar], [vector, vector] (got: %s, %s)", str(self), str(other)), 2)
    end
end

function Vector:__modulo(other)
    if Vector.is(self) and isn(other) then
        return Vector(self.x % other, self.y % other)
    elseif Vector.is(self) and Vector.is(other) then
        return Vector(self.x % other.x, self.y % other.y)
    else
        error(fstr("Vector modulo only supported on operands of type: [vector, scalar], [vector, vector] (got: %s, %s)", str(self), str(other)), 2)
    end
end

function Vector:__minus()
    return Vector(-self.x, -self.y)
end

function Vector:__lessthan(other)
    if Vector.is(self) and Vector.is(other) then
        return self.len < other.len
    else
        error(fstr("Vector comparison only supported on operands of type: [vector, vector] (got: %s, %s)", str(self), str(other)), 2)
    end
end

function Vector:__lessequal(other)
    if Vector.is(self) and Vector.is(other) then
        return self.len <= other.len
    else
        error(fstr("Vector comparison only supported on operands of type: [vector, vector] (got: %s, %s)", str(self), str(other)), 2)
    end
end

function Vector:__tostring()
    return repr[self] or fstr("(%s, %s)", str(self.x), str(self.y))
end

-- Constants
Vector.zero  = Vector( 0,  0)
Vector.one   = Vector( 1,  1)
Vector.left  = Vector(-1,  0)
Vector.right = Vector( 1,  0)
Vector.up    = Vector( 0, -1)
Vector.down  = Vector( 0,  1)

-- Prevent modification
function Vector:__set(key, value)
    error("Attempted to modify an immutable vector", 2)
end

return Vector