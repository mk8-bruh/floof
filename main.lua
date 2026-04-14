floof = require('.')
Object  = floof.object
Element = floof.element

Box = Element:class("Box")

Box.font = love.graphics.newFont(12)

function Box:constructed()
    self.baseW, self.pressedW, self.hoveredW = self.w, self.w + 10, self.w + 5
    self.baseH, self.pressedH, self.hoveredH = self.h, self.h + 10, self.h + 5
end

function Box:__set_w(value)
    self.baseW, self.pressedW, self.hoveredW = value, value + 10, value + 5
    Element:set(self, "w", self.isPressed and self.pressedW or self.isHovered and self.hoveredW or self.baseW)
end

function Box:__set_h(value)
    self.baseH, self.pressedH, self.hoveredH = value, value + 10, value + 5
    Element:set(self, "h", self.isPressed and self.pressedH or self.isHovered and self.hoveredH or self.baseH)
end

function Box:hovered()
    if not self.isPressed then
        Element:set(self, "w", self.hoveredW)
        Element:set(self, "h", self.hoveredH)
    end
end

function Box:unhovered()
    if not self.isPressed then
        Element:set(self, "w", self.baseW)
        Element:set(self, "h", self.baseH)
    end
end

function Box:pressed()
    Element:set(self, "w", self.pressedW)
    Element:set(self, "h", self.pressedH)
end

function Box:released()
    if self.isHovered then
        Element:set(self, "w", self.hoveredW)
        Element:set(self, "h", self.hoveredH)
    else
        Element:set(self, "w", self.baseW)
        Element:set(self, "h", self.baseH)
    end
end

function Box:cancelled()
    if self.isHovered then
        Element:set(self, "w", self.hoveredW)
        Element:set(self, "h", self.hoveredH)
    else
        Element:set(self, "w", self.baseW)
        Element:set(self, "h", self.baseH)
    end
end

function Box:draw()
    love.graphics.rectangle("line", self.l, self.t, self.w, self.h)
    love.graphics.setFont(self.font)
    local label = tostring(self.layoutIndex)
    love.graphics.print(label, self.x - self.font:getWidth(label)/2, self.y - self.font:getHeight()/2)
end

Element.expandSpace = true
Element.spaceAround = true

inputListener = Object{
    isListener = true,
    activated = function(self) self.isListening = true end,
    deactivated = function(self) self.isListening = false end,
    keypressed = function(self, k)
        if k == "x" then
            Element.layoutDirection = "row"
        elseif k == "y" then
            Element.layoutDirection = "column"
        elseif k == "space" then
            Box{w = 30, h = 20}
        elseif k == "backspace" and Element[-1] then
            Element[-1]:delete()
        end
    end
}

fpsCounter = Element{
    inLayout = false,
    z = math.huge,
    align = "top-right",
    font = love.graphics.newFont(14),
    text = "", p = 3,
    update = function(self, dt)
        self.text = ("%d FPS"):format(love.timer.getFPS())
        self.w = self.font:getWidth(self.text) + self.lp + self.rp
        self.h = self.font:getHeight() + self.tp + self.bp
    end,
    draw = function(self)
        love.graphics.setColor(0, 0, 0, 0.5)
        love.graphics.rectangle("fill", self.l, self.t, self.w, self.h)
        love.graphics.setColor(1, 1, 1)
        love.graphics.print(self.text, self.font, self.l + self.lp, self.t + self.tp)
    end
}

Object.initialize(arg)