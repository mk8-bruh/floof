-- Pre-defined hitbox checking functions for different common shapes
local hitboxChecks = {
    -- Rectangle with top-left origin (common for LÖVE)
    cornerRect = function(self, x, y)
        if type(self.x) ~= "number" or type(self.y) ~= "number" or type(self.w) ~= "number" or type(self.h) ~= "number" then
            return false
        end
        local left, top, right, bottom = math.min(self.x, self.x + self.w), math.min(self.y, self.y + self.h), math.max(self.x, self.x + self.w), math.max(self.y, self.y + self.h)
        return x >= left and x <= right and y >= top and y <= bottom
    end,
    
    -- Rectangle with center origin (common for normal people)
    centerRect = function(self, x, y)
        if type(self.x) ~= "number" or type(self.y) ~= "number" or type(self.w) ~= "number" or type(self.h) ~= "number" then
            return false
        end
        return x >= self.x - self.w/2 and x <= self.x + self.w/2 and y >= self.y - self.h/2 and y <= self.y + self.h/2
    end,
    
    -- Circle with center origin
    circle = function(self, x, y)
        if type(self.x) ~= "number" or type(self.y) ~= "number" or type(self.r) ~= "number" then
            return false
        end
        return (x - self.x)^2 + (y - self.y)^2 <= self.r^2
    end,
    
    -- Ellipse with center origin
    ellipse = function(self, x, y)
        if type(self.x) ~= "number" or type(self.y) ~= "number" or type(self.w) ~= "number" or type(self.h) ~= "number" then
            return false
        end
        return (x - self.x)^2 / (self.w/2)^2 + (y - self.y)^2 / (self.h/2)^2 <= 1
    end,
    
    -- Union of all child hitbox checks
    children = function(self, x, y)
        for index, child in ipairs(self.children) do
            if child:check(x, y) then
                return true
            end
        end
        return false
    end,
    
    -- Point hitbox (always returns true if coordinates match)
    point = function(self, x, y)
        if type(self.x) ~= "number" or type(self.y) ~= "number" then
            return false
        end
        return x == self.x and y == self.y
    end,
    
    -- Line segment hitbox
    line = function(self, x, y)
        if type(self.x1) ~= "number" or type(self.y1) ~= "number" or type(self.x2) ~= "number" or type(self.y2) ~= "number" then
            return false
        end
        
        local tolerance = self.tolerance or 5
        local deltaX = self.x2 - self.x1
        local deltaY = self.y2 - self.y1
        local length = math.sqrt(deltaX * deltaX + deltaY * deltaY)
        
        if length == 0 then
            return x == self.x1 and y == self.y1
        end
        
        local t = ((x - self.x1) * deltaX + (y - self.y1) * deltaY) / (length * length)
        t = math.max(0, math.min(1, t))
        
        local closestX = self.x1 + t * deltaX
        local closestY = self.y1 + t * deltaY
        
        local distance = math.sqrt((x - closestX)^2 + (y - closestY)^2)
        return distance <= tolerance
    end,
    
    -- Polygon hitbox (convex polygon)
    polygon = function(self, x, y)
        if not self.vertices or #self.vertices < 3 then
            return false
        end
        
        local inside = false
        local j = #self.vertices
        
        for i = 1, #self.vertices do
            local vertexI = self.vertices[i]
            local vertexJ = self.vertices[j]
            
            if ((vertexI.y > y) ~= (vertexJ.y > y)) and (x < (vertexJ.x - vertexI.x) * (y - vertexI.y) / (vertexJ.y - vertexI.y) + vertexI.x) then
                inside = not inside
            end
            j = i
        end
        
        return inside
    end
}

-- Set default hitbox check
hitboxChecks.default = hitboxChecks.cornerRect

-- Helper function to create custom hitbox checks
local function createHitboxCheck(checkFunction)
    if type(checkFunction) == "function" then
        return checkFunction
    elseif type(checkFunction) == "string" and hitboxChecks[checkFunction] then
        return hitboxChecks[checkFunction]
    elseif type(checkFunction) == "boolean" then
        return function() return checkFunction end
    else
        error(("Invalid hitbox check (got: %s (%s))"):format(tostring(checkFunction), type(checkFunction)), 2)
    end
end

return {
    checks = hitboxChecks,
    create = createHitboxCheck
} 