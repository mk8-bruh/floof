-- FLOOF: Fast Lua Object-Oriented Framework
-- Copyright (c) 2026 Matus Kordos

local PATH = (...):match("^(.*%.).-$") or ""
local floof = require(PATH)

-- cache

local sqrt, sin, cos, asin, atan2 = math.sqrt, math.sin, math.cos, math.asin, math.atan2
local fstr = string.format
local function isn(x) return floof.typeOf(x) == 'number' end
local function ang(x) return math.pi - ((math.pi - x) % (2*math.pi)) end

local reg, repr = {}, {}

-- definition

local Vector = floof:class("Vector")

function Vector:__init(x, y)
    if not (isn(x) and isn(y)) then
        error(fstr("Both vector components must be numbers (got: %s, %s)", floof.typeOf(x), floof.typeOf(y)), 2)
    end

    local k = fstr("(%s, %s)", tostring(x), tostring(y))
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
    if r.len ~= 0 and r.len ~= 1 then
        r.normal = Vector(x / r.len, y / r.len)
    else
        r.normal = self
    end
    reg[k] = r
    repr[self] = k
    
    return self
end

-- methods

function Vector.fromString(s)
    if type(s) == 'string' then
        local x, y = s:match('^%s*[%(%{%[]?(.-)[,;](.-)[%)%}%]]?%s*$')
        if tonumber(x) and tonumber(y) then
            return Vector(tonumber(x), tonumber(y))
        else
            error(fstr("Invalid vector string: %q)", s:gsub("\n", "\\n")), 2)
        end
    else
        error(fstr("Vector string parsing only supported on operands of type: [string] (got: %s)", floof.typeOf(s)), 2)
    end
end

function Vector.polar(a, l)
    if isn(a) and (isn(l) or l == nil) then
        return Vector(cos(a), sin(a)) * (l or 1)
    else
        error(fstr("Both direction and length must be numbers (got: %s, %s)", floof.typeOf(a), floof.typeOf(l)), 2)
    end
end

function Vector:unpack()
    if floof.instanceOf(self, Vector) then
        local r = reg[repr[self]]
        return r.x, r.y
    else
        error(fstr("Vector unpacking only supported on operands of type: [vector] (got: %s)", floof.typeOf(self)))
    end
end

function Vector.dot(a, b)
    if floof.instanceOf(a, Vector) and floof.instanceOf(b, Vector) then
        return a.x * b.x + a.y * b.y
    else
        error(fstr("Dot product only supported on operands of type: [vector, vector] (got: %s, %s)", floof.typeOf(a), floof.typeOf(b)), 2)
    end
end

function Vector.det(a, b)
    if floof.instanceOf(a, Vector) and floof.instanceOf(b, Vector) then
        return a.x * b.y - a.y * b.x
    else
        error(fstr("Cross product only supported on operands of type: [vector, vector] (got: %s, %s)", floof.typeOf(a), floof.typeOf(b)), 2)
    end
end

function Vector.angle(a, b)
    if floof.instanceOf(a, Vector) and floof.instanceOf(b, Vector) then
        return asin(a.normal:dot(b.normal))
    else
        error(fstr("Angle measurement only supported on operands of type: [vector, vector] (got: %s, %s)", floof.typeOf(a), floof.typeOf(b)), 2)
    end
end

function Vector.signedAngle(a, b)
    if floof.instanceOf(a, Vector) and floof.instanceOf(b, Vector) then
        return asin(a.normal:det(b.normal))
    else
        error(fstr("Signed angle measurement only supported on operands of type: [vector, vector] (got: %s, %s)", floof.typeOf(a), floof.typeOf(b)), 2)
    end
end

function Vector.rotate(v, a)
    if floof.instanceOf(v, Vector) and isn(a) then
        local s, c = sin(a), cos(a)
        return Vector(v.x * c - v.y * s, v.x * s + v.y * c)
    else
        error(fstr("Rotation only supported on operands of type: [vector, number] (got: %s, %s)", floof.typeOf(v), floof.typeOf(a)), 2)
    end
end

function Vector.lerp(a, b, t)
    if floof.instanceOf(a, Vector) and floof.instanceOf(b, Vector) and isn(t) then
        return a + (b - a) * t
    else
        error(fstr("Linear interpolation only supported on operands of type: [vector, vector, number] (got: %s, %s, %s)", floof.typeOf(a), floof.typeOf(b), floof.typeOf(t)), 2)
    end
end

function Vector.moveTo(a, b, d)
    if floof.instanceOf(a, Vector) and floof.instanceOf(b, Vector) and isn(d) then
        return a + (b - a).normal * d
    else
        error(fstr("Absolute interpolation only supported on operands of type: [vector, vector, number] (got: %s, %s, %s)", floof.typeOf(a), floof.typeOf(b), floof.typeOf(d)), 2)
    end
end

function Vector.project(a, b)
    if floof.instanceOf(a, Vector) and floof.instanceOf(b, Vector) then
        if a.len == 0 or b.len == 0 then return Vector.zero end
        return Vector.dot(a, b) / b.sqrLen * b
    else
        error(fstr("Projection only supported on operands of type: [vector, vector] (got: %s, %s)", floof.typeOf(a), floof.typeOf(b)), 2)
    end
end

function Vector.setLen(v, l)
    if floof.instanceOf(v, Vector) and isn(l) then
        return v.normal * l
    else
        error(fstr("Length modification only supported on operands of type: [vector, number] (got: %s, %s)", floof.typeOf(v), floof.typeOf(l)), 2)
    end
end

function Vector.maxLen(v, l)
    if floof.instanceOf(v, Vector) and isn(l) then
        return v.normal * math.min(v.len, l)
    else
        error(fstr("Length capping only supported on operands of type: [vector, number] (got: %s, %s)", floof.typeOf(v), floof.typeOf(l)), 2)
    end
end

function Vector.minLen(v, l)
    if floof.instanceOf(v, Vector) and isn(l) then
        return v.normal * math.max(v.len, l)
    else
        error(fstr("Length flooring only supported on operands of type: [vector, number] (got: %s, %s)", floof.typeOf(v), floof.typeOf(l)), 2)
    end
end

function Vector.clampLen(v, a, b)
    if floof.instanceOf(v, Vector) and isn(a) and isn(b) then
        a, b = math.min(a, b), math.max(a, b)
        return v.normal * math.max(a, math.min(b, v.len))
    else
        error(fstr("Length clamping only supported on operands of type: [vector, number, number] (got: %s, %s, %s)", floof.typeOf(v), floof.typeOf(a), floof.typeOf(b)), 2)
    end
end

-- metamethods & operators

function Vector:__get(k)
    if floof.instanceOf(self, Vector) and k ~= "instance" then
        return reg[repr[self]][k]
    end
end

function Vector:__set(key, value)
    if floof.instanceOf(self, Vector) then
        error("Cannot mutate vectors", 2)
    end
end

function Vector:__tostring()
    if floof.instanceOf(self, Vector) then
        return repr[self]
    else
        error(fstr("Vector string representation only supported on operands of type: [vector] (got: %s)", floof.typeOf(self)), 2)
    end
end

function Vector:__invert()
    if floof.instanceOf(self, Vector) then
        return Vector(-self.x, -self.y)
    else
        error(fstr("Vector inversion only supported on operands of type: [vector] (got: %s)", floof.typeOf(self)), 2)
    end
end

function Vector.__add(a, b)
    if floof.instanceOf(a, Vector) and floof.instanceOf(b, Vector) then
        return Vector(a.x + b.x, a.y + b.y)
    else
        error(fstr("Vector addition only supported on operands of type: [vector, vector] (got: %s, %s)", floof.typeOf(a), floof.typeOf(b)), 2)
    end
end

function Vector.__subtract(a, b)
    if floof.instanceOf(a, Vector) and floof.instanceOf(b, Vector) then
        return Vector(a.x - b.x, a.y - b.y)
    else
        error(fstr("Vector subtraction only supported on operands of type: [vector, vector] (got: %s, %s)", floof.typeOf(a), floof.typeOf(b)), 2)
    end
end

function Vector.__multiply(a, b)
    if floof.instanceOf(a, Vector) and floof.instanceOf(b, Vector) then
        return Vector(a.x * b.x, a.y * b.y)
    elseif floof.instanceOf(a, Vector) and isn(b) then
        return Vector(a.x * b, a.y * b)
    elseif isn(a) and floof.instanceOf(b, Vector) then
        return Vector(a * b.x, a * b.y)
    else
        error(fstr("Vector multiplication only supported on operands of type: [vector, vector], [vector, scalar], [scalar, vector] (got: %s, %s)", floof.typeOf(a), floof.typeOf(b)), 2)
    end
end

function Vector.__divide(a, b)
    if floof.instanceOf(a, Vector) and floof.instanceOf(b, Vector) then
        return Vector(a.x / b.x, a.y / b.y)
    elseif floof.instanceOf(a, Vector) and isn(b) then
        return Vector(a.x / b, a.y / b)
    elseif isn(a) and floof.instanceOf(b, Vector) then
        return Vector(a / b.x, a / b.y)
    else
        error(fstr("Vector division only supported on operands of type: [vector, vector], [vector, scalar], [scalar, vector] (got: %s, %s)", floof.typeOf(a), floof.typeOf(b)), 2)
    end
end

function Vector.__power(a, b)
    if floof.instanceOf(a, Vector) and isn(b) then
        return Vector(a.x ^ b, a.y ^ b)
    elseif floof.instanceOf(a, Vector) and floof.instanceOf(b, Vector) then
        return Vector(a.x ^ b.x, a.y ^ b.y)
    else
        error(fstr("Vector exponentiation only supported on operands of type: [vector, scalar], [vector, vector] (got: %s, %s)", floof.typeOf(a), floof.typeOf(b)), 2)
    end
end

function Vector.__modulo(a, b)
    if floof.instanceOf(a, Vector) and isn(b) then
        return Vector(a.x % b, a.y % b)
    elseif floof.instanceOf(a, Vector) and floof.instanceOf(b, Vector) then
        return Vector(a.x % b.x, a.y % b.y)
    else
        error(fstr("Vector modulo only supported on operands of type: [vector, scalar], [vector, vector] (got: %s, %s)", floof.typeOf(a), floof.typeOf(b)), 2)
    end
end

function Vector.__lessthan(a, b)
    if floof.instanceOf(a, Vector) and floof.instanceOf(b, Vector) then
        return a.len < b.len
    else
        error(fstr("Vector comparison only supported on operands of type: [vector, vector] (got: %s, %s)", floof.typeOf(a), floof.typeOf(b)), 2)
    end
end

function Vector.__lessequal(a, b)
    if floof.instanceOf(a, Vector) and floof.instanceOf(b, Vector) then
        return a.len <= b.len
    else
        error(fstr("Vector comparison only supported on operands of type: [vector, vector] (got: %s, %s)", floof.typeOf(a), floof.typeOf(b)), 2)
    end
end

-- constants

Vector.zero  = Vector( 0,  0)
Vector.one   = Vector( 1,  1)
Vector.left  = Vector(-1,  0)
Vector.right = Vector( 1,  0)
Vector.up    = Vector( 0, -1)
Vector.down  = Vector( 0,  1)

return Vector