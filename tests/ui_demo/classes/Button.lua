-- Button Class for FLOOF UI Demo
local class = require("class")
local Object = require("object")

local Button = class("Button", Object)

function Button:init(data)
    self.super.init(self, data)
    self.text = data.text or "Button"
    self.color = data.color or {0.2, 0.6, 1.0, 1.0}
    self.hoverColor = data.hoverColor or {0.3, 0.7, 1.0, 1.0}
    self.pressColor = data.pressColor or {0.1, 0.5, 0.9, 1.0}
    self.textColor = data.textColor or {1, 1, 1, 1}
    self.font = love.graphics.newFont(14)
    self._check = Object.checks.cornerRect
end

function Button:draw()
    local color = self.color
    if self.isPressed then
        color = self.pressColor
    elseif self.isHovered then
        color = self.hoverColor
    end
    
    love.graphics.setColor(unpack(color))
    love.graphics.rectangle("fill", self.x, self.y, self.w, self.h)
    
    love.graphics.setColor(0, 0, 0, 0.3)
    love.graphics.rectangle("line", self.x, self.y, self.w, self.h)
    
    love.graphics.setColor(unpack(self.textColor))
    love.graphics.setFont(self.font)
    local textW = self.font:getWidth(self.text)
    local textH = self.font:getHeight()
    love.graphics.print(self.text, 
        self.x + (self.w - textW) / 2, 
        self.y + (self.h - textH) / 2)
end

function Button:pressed(x, y, id)
    self:send("buttonPressed", self.text)
    return true
end

return Button 