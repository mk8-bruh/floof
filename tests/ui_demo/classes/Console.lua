-- Console Class for FLOOF UI Demo
local class = require("class")
local Object = require("object")
local Array = require("array")

local Console = class("Console", Object)

function Console:init(data)
    self.super.init(self, data)
    self.lines = Array()
    self.maxLines = data.maxLines or 100
    self.font = love.graphics.newFont(12)
    self.scrollY = 0
    self.lineHeight = 16
    self.padding = 10
    self._check = Object.checks.cornerRect
end

function Console:addLine(text)
    self.lines:append({
        text = text,
        time = os.date("%H:%M:%S")
    })
    
    if self.lines.length > self.maxLines then
        self.lines:pop(1)
    end
    
    -- Auto-scroll to bottom
    self.scrollY = math.max(0, (self.lines.length * self.lineHeight) - (self.h - self.padding * 2))
end

function Console:draw()
    -- Background
    love.graphics.setColor(0.1, 0.1, 0.1, 0.9)
    love.graphics.rectangle("fill", self.x, self.y, self.w, self.h)
    
    -- Border
    love.graphics.setColor(0.3, 0.3, 0.3, 1)
    love.graphics.rectangle("line", self.x, self.y, self.w, self.h)
    
    -- Title
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setFont(love.graphics.getFont())
    love.graphics.print("Console", self.x + self.padding, self.y + 5)
    
    -- Lines
    love.graphics.setFont(self.font)
    love.graphics.setScissor(self.x + self.padding, self.y + 25, self.w - self.padding * 2, self.h - 30)
    
    local y = self.y + 25 - self.scrollY
    for i = 1, self.lines:length() do
        local line = self.lines[i]
        if y + self.lineHeight > self.y + 25 and y < self.y + self.h - 5 then
            love.graphics.setColor(0.7, 0.7, 0.7, 1)
            love.graphics.print(line.time, self.x + self.padding, y)
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.print(line.text, self.x + self.padding + 60, y)
        end
        y = y + self.lineHeight
    end
    
    love.graphics.setScissor()
end

function Console:scrolled(dy)
    self.scrollY = math.max(0, math.min(self.scrollY + dy * 30, 
        (self.lines:length() * self.lineHeight) - (self.h - self.padding * 2)))
    return true
end

return Console 