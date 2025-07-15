-- Label Class for FLOOF UI Demo
local class = require("class")
local Object = require("object")

local Label = class("Label", Object)

function Label:init(data)
    self.super.init(self, data)
    self.text = data.text or "Label"
    self.color = data.color or {1, 1, 1, 1}
    self.font = data.font or love.graphics.getFont()
    self._check = Object.checks.cornerRect
end

function Label:draw()
    love.graphics.setColor(unpack(self.color))
    love.graphics.setFont(self.font)
    love.graphics.print(self.text, self.x, self.y)
end

return Label 