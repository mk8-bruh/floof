-- Panel Class for FLOOF UI Demo
local class = require("class")
local Object = require("object")

local Panel = class("Panel", Object)

function Panel:init(data)
    self.super.init(self, data)
    self.title = data.title or "Panel"
    self.backgroundColor = data.backgroundColor or {0.15, 0.15, 0.15, 0.8}
    self.borderColor = data.borderColor or {0.4, 0.4, 0.4, 1}
    self._check = Object.checks.cornerRect
end

function Panel:draw()
    -- Background
    love.graphics.setColor(unpack(self.backgroundColor))
    love.graphics.rectangle("fill", self.x, self.y, self.w, self.h)
    
    -- Border
    love.graphics.setColor(unpack(self.borderColor))
    love.graphics.rectangle("line", self.x, self.y, self.w, self.h)
    
    -- Title
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print(self.title, self.x + 10, self.y + 10)
end

return Panel 