floof = require('.')
Object  = floof.object
Element = floof.element

Box = Element:class("Box")

Box.font = love.graphics.newFont(12)

function Box:hovered()
    self.w, self.h = self.w + 5, self.h + 5
end

function Box:unhovered()
    self.w, self.h = self.w - 5, self.h - 5
end

function Box:draw()
    love.graphics.rectangle("line", self.l, self.t, self.w, self.h)
    love.graphics.setFont(self.font)
    local label = tostring(self.layoutIndex)
    love.graphics.print(label, self.x - self.font:getWidth(label)/2, self.y - self.font:getHeight()/2)
end

Element.space = 10
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

profiler = Element{
    inLayout = false,
    z = math.huge,
    align = "bottom-right",
    width = "30%", height = "30%",
    baseColor = {0.5, 0.5, 0.5},
    segments = 30,
    portions = {
        {size = 0, color = {1, 1, 0}},
        {size = 0, color = {0.2, 0.5, 1}},
        {size = 0, color = {1, 0.5, 0.2}},
    },
    check = function(self, x, y)
        return (x - self.x)^2 + (y - self.y)^2 <= math.min(self.w/2, self.h/2)^2
    end,
    update = function(self, dt)
        if Object.profiler.timelines.entries > 0 then
            local t = Object.profiler.sums.total
            self.portions[1].size = Object.profiler.sums.events / t
            self.portions[2].size = Object.profiler.sums.update / t
            self.portions[3].size = Object.profiler.sums.render / t
        end
    end,
    draw = function(self)
        local r = math.min(self.w/2, self.h/2)
        love.graphics.setColor(self.baseColor)
        love.graphics.circle("fill", self.x, self.y, r, self.segments)
        local a = -math.pi/2
        for i, portion in ipairs(self.portions) do
            love.graphics.setColor(portion.color)
            local d = 2 * math.pi * portion.size
            love.graphics.arc("fill", self.x, self.y, r, a, a + d, math.max(self.segments * portion.size, 1))
            a = a + d
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