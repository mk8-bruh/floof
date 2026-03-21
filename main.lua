floof = require('.')

Object = floof.object

function Object:check(x, y)
    return x >= self.x and x <= self.x + self.w
       and y >= self.y and y <= self.y + self.h
end

function Object:dragged(x, y, dx, dy)
    self.x, self.y = self.x + dx, self.y + dy
end

local levelColors = {
    {1, 1, 1}, {0, 1, 0}, {0, 0.25, 1}
}
function Object:draw()
    local r, g, b = unpack(levelColors[self.hierarchyLevel + 1])
    love.graphics.setColor(r, g, b, self.isPressed and 0.75 or 0.25)
    love.graphics.rectangle("fill", self.x, self.y, self.w, self.h)
    love.graphics.setLineWidth(3)
    love.graphics.setColor(r, g, b)
    love.graphics.rectangle("line", self.x, self.y, self.w, self.h)
    if self.isHovered or self.behindHover then
        love.graphics.setLineWidth(1)
        love.graphics.setColor(self.isHovered and 1 or 0, 0, 0)
        love.graphics.rectangle("line", self.x, self.y, self.w, self.h)
    end
end

local A = Object{name = "A", z = -1, x =  20, y = 20, w = 100, h = 100}
local B = Object{name = "B", z =  1, x = 130, y = 20, w = 100, h = 100}

local AA = Object{name = "AA", parent = A, z = -1, x =  15, y = 15, w = 50, h = 50}
local AB = Object{name = "AB", parent = A, z =  1, x =  75, y = 75, w = 50, h = 50}
local BA = Object{name = "BA", parent = B, z = -1, x = 125, y = 15, w = 50, h = 50}
local BB = Object{name = "BB", parent = B, z =  1, x = 185, y = 75, w = 50, h = 50}

local AAA = Object{name = "AAA", parent = AA, z = -1, x =  10, y =  10, w = 25, h = 25}
local AAB = Object{name = "AAB", parent = AA, z =  1, x =  45, y =  45, w = 25, h = 25}
local BBA = Object{name = "BBA", parent = BB, z = -1, x = 180, y =  70, w = 25, h = 25}
local BBB = Object{name = "BBB", parent = BB, z =  1, x = 215, y = 105, w = 25, h = 25}

Object {
    name = "fpsCounter", z = 2, font = love.graphics.newFont(12), check = false,
    draw = function(self)
        local txt = string.format("%d FPS", love.timer.getFPS())
        love.graphics.print(txt, self.font, love.graphics.getWidth() - self.font:getWidth(txt), 0)
    end
}

Object {
    name = "pointer", z = math.huge, isListener = true, isListening = true, check = false,
    draw = function(self)
        if Object.ownPointer then
            love.graphics.setColor(1, 0, 0)
            love.graphics.setLineWidth(1)
            love.graphics.line(
                Object.pointerX - 5, Object.pointerY,
                Object.pointerX + 5, Object.pointerY
            )
            love.graphics.line(
                Object.pointerX, Object.pointerY - 5,
                Object.pointerX, Object.pointerY + 5
            )
        end
    end,
    keypressed = function(self, key)
        if key == "escape" then
            Object.ownPointer = not Object.ownPointer
        end
    end,
    mousemoved = function(self, dx, dy)
        Object:movePointer(Object.pointerX + dx, Object.pointerY + dy)
    end,
    mousepressed = function(self, ...)
        Object:pressPointer(...)
    end,
    mousereleased = function(self, ...)
        Object:releasePointer(...)
    end
}

Object.initialize(arg)

function love.errorhandler(msg)
    print(debug.traceback(msg, 2))
    Object:render()
    return function()
        love.event.pump()
        for ev in love.event.poll() do
            if ev == "quit" then return 1 end
        end
        love.timer.sleep(0.01)
    end
end