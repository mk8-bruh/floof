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
    
    -- Polygon hitbox (convex polygon) - uses LOVE2D format {x1, y1, x2, y2, x3, y3, ...}
    polygon = function(self, x, y)
        if not self.vertices or #self.vertices < 6 then
            return false
        end
        
        local inside = false
        local j = #self.vertices - 1
        
        for i = 1, #self.vertices, 2 do
            local vertexIx = self.vertices[i]
            local vertexIy = self.vertices[i + 1]
            local vertexJx = self.vertices[j]
            local vertexJy = self.vertices[j + 1]
            
            if ((vertexIy > y) ~= (vertexJy > y)) and (x < (vertexJx - vertexIx) * (y - vertexIy) / (vertexJy - vertexIy) + vertexIx) then
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