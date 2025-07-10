local InputTypes = {}

-- Button input type (true/false)
local Button = {}
Button.__index = Button

function Button.new(sources, processors)
    local self = setmetatable({}, Button)
    self.sources = sources or {}
    self.processors = processors or {}
    self.value = false
    self.pressed = false
    self.released = false
    
    -- Wrap in proxy for safety
    local buttonMethods = {
        handleEvent = true, getValue = true
    }
    
    return setmetatable(self, {
        __index = function(t, k)
            return Button[k] or rawget(t, k)
        end,
        __newindex = function(t, k, v)
            if buttonMethods[k] then
                error(("Cannot override the %q method"):format(tostring(k)), 2)
            end
            rawset(t, k, v)
        end,
        __metatable = false,
        __tostring = function() return "Button" end
    })
end

function Button:handleEvent(eventType, ...)
    if eventType == "keypressed" then
        local key = ...
        for _, source in ipairs(self.sources) do
            if source.type == "key" and source.value == key then
                self.value = true
                self.pressed = true
                return true
            end
        end
    elseif eventType == "keyreleased" then
        local key = ...
        for _, source in ipairs(self.sources) do
            if source.type == "key" and source.value == key then
                self.value = false
                self.released = true
                return true
            end
        end
    elseif eventType == "mousepressed" then
        local x, y, button = ...
        for _, source in ipairs(self.sources) do
            if source.type == "mouse" and source.value == button then
                self.value = true
                self.pressed = true
                return true
            end
        end
    elseif eventType == "mousereleased" then
        local x, y, button = ...
        for _, source in ipairs(self.sources) do
            if source.type == "mouse" and source.value == button then
                self.value = false
                self.released = true
                return true
            end
        end
    elseif eventType == "joystickpressed" then
        local joystick, button = ...
        for _, source in ipairs(self.sources) do
            if source.type == "joystick" and source.joystick == joystick and source.value == button then
                self.value = true
                self.pressed = true
                return true
            end
        end
    elseif eventType == "joystickreleased" then
        local joystick, button = ...
        for _, source in ipairs(self.sources) do
            if source.type == "joystick" and source.joystick == joystick and source.value == button then
                self.value = false
                self.released = true
                return true
            end
        end
    end
    return false
end

function Button:getValue()
    local value = self.value
    for _, processor in ipairs(self.processors) do
        value = processor.func(value, unpack(processor.args))
    end
    return value
end

-- Axis input type (-1 to 1)
local Axis = {}
Axis.__index = Axis

function Axis.new(sources, processors)
    local self = setmetatable({}, Axis)
    self.sources = sources or {}
    self.processors = processors or {}
    self.value = 0
    
    -- Wrap in proxy for safety
    local axisMethods = {
        handleEvent = true, getValue = true
    }
    
    return setmetatable(self, {
        __index = function(t, k)
            return Axis[k] or rawget(t, k)
        end,
        __newindex = function(t, k, v)
            if axisMethods[k] then
                error(("Cannot override the %q method"):format(tostring(k)), 2)
            end
            rawset(t, k, v)
        end,
        __metatable = false,
        __tostring = function() return "Axis" end
    })
end

function Axis:handleEvent(eventType, ...)
    if eventType == "joystickaxis" then
        local joystick, axis, value = ...
        for _, source in ipairs(self.sources) do
            if source.type == "joystick" and source.joystick == joystick and source.value == axis then
                local sourceValue = value
                
                -- Apply source-specific processors
                for _, processor in ipairs(source.processors or {}) do
                    sourceValue = processor.func(sourceValue, unpack(processor.args))
                end
                
                -- Clamp to -1 to 1 range
                sourceValue = math.max(-1, math.min(1, sourceValue))
                self.value = sourceValue
                return true
            end
        end
    elseif eventType == "keypressed" then
        local key = ...
        for _, source in ipairs(self.sources) do
            if source.type == "key_positive" and source.value == key then
                self.value = math.max(self.value, 1)
                return true
            elseif source.type == "key_negative" and source.value == key then
                self.value = math.min(self.value, -1)
                return true
            end
        end
    elseif eventType == "keyreleased" then
        local key = ...
        for _, source in ipairs(self.sources) do
            if source.type == "key_positive" and source.value == key then
                self.value = 0
                return true
            elseif source.type == "key_negative" and source.value == key then
                self.value = 0
                return true
            end
        end
    elseif eventType == "mousepressed" then
        local x, y, button = ...
        for _, source in ipairs(self.sources) do
            if source.type == "mouse_positive" and source.value == button then
                self.value = math.max(self.value, 1)
                return true
            elseif source.type == "mouse_negative" and source.value == button then
                self.value = math.min(self.value, -1)
                return true
            end
        end
    elseif eventType == "mousereleased" then
        local x, y, button = ...
        for _, source in ipairs(self.sources) do
            if source.type == "mouse_positive" and source.value == button then
                self.value = 0
                return true
            elseif source.type == "mouse_negative" and source.value == button then
                self.value = 0
                return true
            end
        end
    elseif eventType == "joystickpressed" then
        local joystick, button = ...
        for _, source in ipairs(self.sources) do
            if source.type == "joystick_positive" and source.joystick == joystick and source.value == button then
                self.value = math.max(self.value, 1)
                return true
            elseif source.type == "joystick_negative" and source.joystick == joystick and source.value == button then
                self.value = math.min(self.value, -1)
                return true
            end
        end
    elseif eventType == "joystickreleased" then
        local joystick, button = ...
        for _, source in ipairs(self.sources) do
            if source.type == "joystick_positive" and source.joystick == joystick and source.value == button then
                self.value = 0
                return true
            elseif source.type == "joystick_negative" and source.joystick == joystick and source.value == button then
                self.value = 0
                return true
            end
        end
    end
    return false
end

function Axis:getValue()
    local value = self.value
    for _, processor in ipairs(self.processors) do
        value = processor.func(value, unpack(processor.args))
    end
    return value
end

-- Vector input type (x, y components)
local Vector = {}
Vector.__index = Vector

function Vector.new(sources, processors)
    local self = setmetatable({}, Vector)
    self.sources = sources or {}
    self.processors = processors or {}
    self.value = {x = 0, y = 0}
    self.delta = {x = 0, y = 0}
    self.lastValue = {x = 0, y = 0}
    
    -- Wrap in proxy for safety
    local vectorMethods = {
        handleEvent = true, getValue = true, getDelta = true
    }
    
    return setmetatable(self, {
        __index = function(t, k)
            return Vector[k] or rawget(t, k)
        end,
        __newindex = function(t, k, v)
            if vectorMethods[k] then
                error(("Cannot override the %q method"):format(tostring(k)), 2)
            end
            rawset(t, k, v)
        end,
        __metatable = false,
        __tostring = function() return "Vector" end
    })
end

function Vector:handleEvent(eventType, ...)
    if eventType == "joystickaxis" then
        local joystick, axis, value = ...
        for _, source in ipairs(self.sources) do
            if source.type == "axis_composite" then
                if source.x_axis and source.x_axis.joystick == joystick and source.x_axis.value == axis then
                    self.lastValue.x = self.value.x
                    self.value.x = value
                    self.delta.x = self.value.x - self.lastValue.x
                    return true
                elseif source.y_axis and source.y_axis.joystick == joystick and source.y_axis.value == axis then
                    self.lastValue.y = self.value.y
                    self.value.y = value
                    self.delta.y = self.value.y - self.lastValue.y
                    return true
                end
            end
        end
    elseif eventType == "mousemoved" then
        local x, y, dx, dy = ...
        for _, source in ipairs(self.sources) do
            if source.type == "mouse_position" then
                self.lastValue.x = self.value.x
                self.lastValue.y = self.value.y
                self.value.x = x
                self.value.y = y
                self.delta.x = self.value.x - self.lastValue.x
                self.delta.y = self.value.y - self.lastValue.y
                return true
            elseif source.type == "mouse_delta" then
                self.value.x = dx
                self.value.y = dy
                self.delta.x = dx
                self.delta.y = dy
                return true
            end
        end
    end
    return false
end

function Vector:getValue()
    local value = {x = self.value.x, y = self.value.y}
    for _, processor in ipairs(self.processors) do
        value = processor.func(value, unpack(processor.args))
    end
    return value
end

function Vector:getDelta()
    local delta = {x = self.delta.x, y = self.delta.y}
    for _, processor in ipairs(self.processors) do
        delta = processor.func(delta, unpack(processor.args))
    end
    return delta
end

-- Wrap module export in proxy for safety
local module = {
    Button = Button,
    Axis = Axis,
    Vector = Vector
}

return setmetatable(module, {
    __index = function(_, k) 
        return module[k] 
    end,
    __newindex = function() 
        error("Cannot modify types module: it is read-only", 2)
    end,
    __metatable = false,
    __tostring = function() return "FLOOF types module" end
}) 