local InputTypes = require("input.types")
local Processors = require("input.processors")

local Control = {}
Control.__index = Control

function Control.new(config)
    local self = setmetatable({}, Control)
    
    -- Validate config
    if not config.type then
        error("Control must have a type (button, axis, vector)")
    end
    
    if not config.bindings then
        error("Control must have bindings")
    end
    
    self.name = config.name
    self.type = config.type
    self.bindings = config.bindings
    self.processors = config.processors or {}
    self.enabled = config.enabled ~= false
    
    -- Create input type instance
    if self.type == "button" then
        self.input = InputTypes.Button.new(self.bindings, self.processors)
    elseif self.type == "axis" then
        self.input = InputTypes.Axis.new(self.bindings, self.processors)
    elseif self.type == "vector" then
        self.input = InputTypes.Vector.new(self.bindings, self.processors)
    else
        error("Invalid control type: " .. self.type)
    end
    
    -- Wrap in proxy for safety
    local controlMethods = {
        handleEvent = true, update = true, getValue = true, getDelta = true,
        isPressed = true, isReleased = true, isDown = true, rebind = true,
        addProcessor = true, removeProcessor = true, serialize = true, loadFromData = true
    }
    
    return setmetatable(self, {
        __index = function(t, k)
            return Control[k] or rawget(t, k)
        end,
        __newindex = function(t, k, v)
            if controlMethods[k] then
                error(("Cannot override the %q method"):format(tostring(k)), 2)
            end
            rawset(t, k, v)
        end,
        __metatable = false,
        __tostring = function() return ("Control: %s"):format(self.name or "unnamed") end
    })
end

function Control:handleEvent(eventType, ...)
    if self.enabled and self.input then
        self.input:handleEvent(eventType, ...)
    end
end

function Control:update()
    -- No longer needed for event-based system
    -- Keep for backward compatibility
end

function Control:getValue()
    if not self.enabled or not self.input then
        return self.type == "vector" and {x = 0, y = 0} or 0
    end
    return self.input:getValue()
end

function Control:getDelta()
    if not self.enabled or not self.input or self.type ~= "vector" then
        return {x = 0, y = 0}
    end
    return self.input:getDelta()
end

function Control:isPressed()
    if not self.enabled or not self.input or self.type ~= "button" then
        return false
    end
    return self.input.pressed
end

function Control:isReleased()
    if not self.enabled or not self.input or self.type ~= "button" then
        return false
    end
    return self.input.released
end

function Control:isDown()
    if not self.enabled or not self.input or self.type ~= "button" then
        return false
    end
    return self.input.value
end

function Control:rebind(newBindings)
    self.bindings = newBindings
    
    -- Recreate input instance with new bindings
    if self.type == "button" then
        self.input = InputTypes.Button.new(self.bindings, self.processors)
    elseif self.type == "axis" then
        self.input = InputTypes.Axis.new(self.bindings, self.processors)
    elseif self.type == "vector" then
        self.input = InputTypes.Vector.new(self.bindings, self.processors)
    end
end

function Control:addProcessor(processorName, ...)
    local processor = Processors[processorName]
    if not processor then
        error("Unknown processor: " .. processorName)
    end
    
    table.insert(self.processors, {
        func = processor,
        args = {...}
    })
    
    -- Recreate input instance with new processors
    if self.type == "button" then
        self.input = InputTypes.Button.new(self.bindings, self.processors)
    elseif self.type == "axis" then
        self.input = InputTypes.Axis.new(self.bindings, self.processors)
    elseif self.type == "vector" then
        self.input = InputTypes.Vector.new(self.bindings, self.processors)
    end
end

function Control:removeProcessor(processorName)
    for i = #self.processors, 1, -1 do
        if self.processors[i].func == Processors[processorName] then
            table.remove(self.processors, i)
        end
    end
    
    -- Recreate input instance with updated processors
    if self.type == "button" then
        self.input = InputTypes.Button.new(self.bindings, self.processors)
    elseif self.type == "axis" then
        self.input = InputTypes.Axis.new(self.bindings, self.processors)
    elseif self.type == "vector" then
        self.input = InputTypes.Vector.new(self.bindings, self.processors)
    end
end

function Control:serialize()
    local data = {
        name = self.name,
        type = self.type,
        bindings = self.bindings,
        enabled = self.enabled
    }
    
    -- Only include processors if there are any
    if #self.processors > 0 then
        data.processors = {}
        for _, processor in ipairs(self.processors) do
            -- Note: This is a simplified serialization
            -- In a real implementation, you'd need to handle function serialization
            table.insert(data.processors, {
                name = "custom", -- Would need to store processor name
                args = processor.args
            })
        end
    end
    
    return data
end

function Control:loadFromData(data)
    if data.name then
        self.name = data.name
    end
    
    if data.type then
        self.type = data.type
    end
    
    if data.bindings then
        self:rebind(data.bindings)
    end
    
    if data.enabled ~= nil then
        self.enabled = data.enabled
    end
    
    if data.processors then
        -- Clear existing processors and add new ones
        for _, processor in ipairs(data.processors) do
            self:addProcessor(processor.name, unpack(processor.args or {}))
        end
    end
end

-- Control Scheme
local ControlScheme = {}
ControlScheme.__index = ControlScheme

function ControlScheme.new(name, controls)
    local self = setmetatable({}, ControlScheme)
    
    self.name = name
    self.controls = {}
    self.modifiedControls = {} -- Track which controls have been modified
    
    -- Add controls
    if controls then
        for _, controlConfig in pairs(controls) do
            self:addControl(controlConfig)
        end
    end
    
    -- Wrap in proxy for safety
    local schemeMethods = {
        addControl = true, getControl = true, removeControl = true, handleEvent = true,
        update = true, serialize = true, loadFromData = true
    }
    
    return setmetatable(self, {
        __index = function(t, k)
            return ControlScheme[k] or rawget(t, k)
        end,
        __newindex = function(t, k, v)
            if schemeMethods[k] then
                error(("Cannot override the %q method"):format(tostring(k)), 2)
            end
            rawset(t, k, v)
        end,
        __metatable = false,
        __tostring = function() return ("ControlScheme: %s"):format(self.name or "unnamed") end
    })
end

function ControlScheme:addControl(controlConfig)
    local control = Control.new(controlConfig)
    self.controls[control.name] = control
    return control
end

function ControlScheme:getControl(name)
    return self.controls[name]
end

function ControlScheme:removeControl(name)
    self.controls[name] = nil
    self.modifiedControls[name] = nil
end

function ControlScheme:handleEvent(eventType, ...)
    for _, control in pairs(self.controls) do
        control:handleEvent(eventType, ...)
    end
end

function ControlScheme:update()
    -- No longer needed for event-based system
    -- Keep for backward compatibility
end

function ControlScheme:serialize()
    local data = {
        name = self.name,
        controls = {}
    }
    
    for controlName, control in pairs(self.controls) do
        data.controls[controlName] = control:serialize()
    end
    
    return data
end

function ControlScheme:loadFromData(data)
    if data.name then
        self.name = data.name
    end
    
    if data.controls then
        for controlName, controlData in pairs(data.controls) do
            local control = self.controls[controlName]
            if control then
                control:loadFromData(controlData)
            end
        end
    end
end

-- Wrap in proxy for safety
local schemeMethods = {
    addControl = true, getControl = true, removeControl = true, handleEvent = true,
    update = true, serialize = true, loadFromData = true
}

-- Wrap module export in proxy for safety
local module = {
    Control = Control,
    ControlScheme = ControlScheme
}

return setmetatable(module, {
    __index = function(_, k) 
        return module[k] 
    end,
    __newindex = function() 
        error("Cannot modify control module: it is read-only", 2)
    end,
    __metatable = false,
    __tostring = function() return "FLOOF control module" end
}) 