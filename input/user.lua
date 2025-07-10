local ControlSystem = require("input.control")
local DeviceSystem = require("input.devices")

local InputUser = {}
InputUser.__index = InputUser

function InputUser.new(controlScheme, pairedDevices)
    local self = setmetatable({}, InputUser)
    
    if not controlScheme then
        error("InputUser requires a control scheme")
    end
    
    self.controlScheme = controlScheme
    self.pairedDevices = pairedDevices or {} -- Array of device IDs
    self.enabled = true
    self.deviceManager = DeviceSystem.DeviceManager.new()
    
    -- Event registry for control state changes
    self.eventRegistry = {}
    self.lastControlStates = {}
    
    -- Create user's own copy of controls from the scheme
    self.controls = {}
    for controlName, schemeControl in pairs(controlScheme.controls) do
        -- Create a new control instance with the same configuration
        local controlConfig = {
            name = schemeControl.name,
            type = schemeControl.type,
            bindings = {}, -- Start with empty bindings
            processors = {},
            enabled = schemeControl.enabled
        }
        
        -- Copy bindings from scheme
        for _, binding in ipairs(schemeControl.bindings) do
            table.insert(controlConfig.bindings, binding)
        end
        
        -- Copy processors from scheme
        for _, processor in ipairs(schemeControl.processors) do
            table.insert(controlConfig.processors, processor)
        end
        
        self.controls[controlName] = ControlSystem.Control.new(controlConfig)
    end
    
    -- Validate paired devices
    for _, deviceId in ipairs(self.pairedDevices) do
        local device = self.deviceManager:getDevice(deviceId)
        if not device then
            error("Paired device not found: " .. deviceId)
        end
    end
    
    -- Wrap in proxy for safety
    local userMethods = {
        handleEvent = true, update = true, getControl = true, getValue = true,
        getDelta = true, isPressed = true, isReleased = true, isDown = true,
        rebindControl = true, addProcessor = true, removeProcessor = true,
        setEnabled = true, isEnabled = true, pairDevice = true, unpairDevice = true,
        getPairedDevices = true, clearPairedDevices = true, onControlChanged = true,
        offControlChanged = true, checkControlStateChanges = true, serialize = true,
        loadFromData = true, saveControlRebind = true, loadControlRebind = true,
        saveAllRebinds = true, loadAllRebinds = true
    }
    
    return setmetatable(self, {
        __index = function(t, k)
            return InputUser[k] or rawget(t, k)
        end,
        __newindex = function(t, k, v)
            if userMethods[k] then
                error(("Cannot override the %q method"):format(tostring(k)), 2)
            end
            rawset(t, k, v)
        end,
        __metatable = false,
        __tostring = function() return "InputUser" end
    })
end

function InputUser:handleEvent(eventType, ...)
    if not self.enabled then
        return
    end
    
    -- Route event to user's own controls
    for _, control in pairs(self.controls) do
        control:handleEvent(eventType, ...)
    end
end

function InputUser:update()
    -- No longer needed for event-based system
    -- Keep for backward compatibility
end

function InputUser:getControl(controlName)
    if not self.enabled then
        return nil
    end
    
    local control = self.controls[controlName]
    if not control then
        return nil
    end
    
    -- Check if control has any bindings from paired devices
    if #self.pairedDevices > 0 then
        local hasPairedBinding = false
        for _, binding in ipairs(control.bindings) do
            if self:isBindingFromPairedDevice(binding) then
                hasPairedBinding = true
                break
            end
        end
        
        -- If control has no paired device bindings, return nil
        if not hasPairedBinding then
            return nil
        end
    end
    
    return control
end

function InputUser:isBindingFromPairedDevice(binding)
    if #self.pairedDevices == 0 then
        return true -- No paired devices means all bindings are valid
    end
    
    local deviceType = self:getBindingDeviceType(binding)
    if not deviceType then
        return false
    end
    
    for _, deviceId in ipairs(self.pairedDevices) do
        local device = self.deviceManager:getDevice(deviceId)
        if device and device.type == deviceType then
            return true
        end
    end
    
    return false
end

function InputUser:getBindingDeviceType(binding)
    if binding.type == "key" then
        return DeviceSystem.TYPES.KEYBOARD
    elseif binding.type == "mouse" or binding.type == "mouse_positive" or binding.type == "mouse_negative" then
        return DeviceSystem.TYPES.MOUSE
    elseif binding.type == "joystick" or binding.type == "joystick_positive" or binding.type == "joystick_negative" then
        return DeviceSystem.TYPES.JOYSTICK
    elseif binding.type == "axis_composite" then
        return DeviceSystem.TYPES.JOYSTICK
    end
    
    return nil
end

function InputUser:getValue(controlName)
    local control = self:getControl(controlName)
    return control and control:getValue() or (control and control.type == "vector" and {x = 0, y = 0} or 0)
end

function InputUser:getDelta(controlName)
    local control = self:getControl(controlName)
    return control and control:getDelta() or {x = 0, y = 0}
end

function InputUser:isPressed(controlName)
    local control = self:getControl(controlName)
    return control and control:isPressed() or false
end

function InputUser:isReleased(controlName)
    local control = self:getControl(controlName)
    return control and control:isReleased() or false
end

function InputUser:isDown(controlName)
    local control = self:getControl(controlName)
    return control and control:isDown() or false
end

function InputUser:rebindControl(controlName, newBindings)
    if not self.enabled then
        return false
    end
    
    local control = self.controls[controlName]
    if not control then
        return false
    end
    
    -- Validate bindings
    for _, binding in ipairs(newBindings) do
        local valid, error = self.deviceManager:validateBinding(binding)
        if not valid then
            print("Warning: Invalid binding for control " .. controlName .. ": " .. error)
            return false
        end
    end
    
    return control:rebind(newBindings)
end

-- Save a single control's rebind to a file
function InputUser:saveControlRebind(controlName, filename)
    local control = self.controls[controlName]
    if not control then
        return false, "Control not found: " .. controlName
    end
    
    local data = {
        controlName = controlName,
        bindings = control.bindings,
        processors = control.processors
    }
    
    return Config.save(data, filename)
end

-- Load a single control's rebind from a file
function InputUser:loadControlRebind(controlName, filename)
    local control = self.controls[controlName]
    if not control then
        return false, "Control not found: " .. controlName
    end
    
    local data = Config.load(filename)
    if not data then
        return false, "Failed to load rebind file: " .. filename
    end
    
    if data.bindings then
        control:rebind(data.bindings)
    end
    
    if data.processors then
        -- Clear existing processors and add new ones
        for _, processor in ipairs(data.processors) do
            control:addProcessor(processor.name, unpack(processor.args or {}))
        end
    end
    
    return true
end

-- Save all user rebinds to a file
function InputUser:saveAllRebinds(filename)
    local data = {
        userRebinds = {}
    }
    
    for controlName, control in pairs(self.controls) do
        data.userRebinds[controlName] = {
            bindings = control.bindings,
            processors = control.processors
        }
    end
    
    return Config.save(data, filename)
end

-- Load all user rebinds from a file
function InputUser:loadAllRebinds(filename)
    local data = Config.load(filename)
    if not data then
        return false, "Failed to load rebinds file: " .. filename
    end
    
    if data.userRebinds then
        for controlName, rebindData in pairs(data.userRebinds) do
            local control = self.controls[controlName]
            if control then
                if rebindData.bindings then
                    control:rebind(rebindData.bindings)
                end
                
                if rebindData.processors then
                    -- Clear existing processors and add new ones
                    for _, processor in ipairs(rebindData.processors) do
                        control:addProcessor(processor.name, unpack(processor.args or {}))
                    end
                end
            end
        end
    end
    
    return true
end

function InputUser:addProcessor(controlName, processorName, ...)
    if not self.enabled then
        return false
    end
    
    local control = self.controlScheme:getControl(controlName)
    if not control then
        return false
    end
    
    control:addProcessor(processorName, ...)
    return true
end

function InputUser:removeProcessor(controlName, processorName)
    if not self.enabled then
        return false
    end
    
    local control = self.controlScheme:getControl(controlName)
    if not control then
        return false
    end
    
    control:removeProcessor(processorName)
    return true
end

function InputUser:setEnabled(enabled)
    self.enabled = enabled
end

function InputUser:isEnabled()
    return self.enabled
end

function InputUser:pairDevice(deviceId)
    if not self.deviceManager:getDevice(deviceId) then
        return false
    end
    
    for _, pairedId in ipairs(self.pairedDevices) do
        if pairedId == deviceId then
            return true -- Already paired
        end
    end
    
    table.insert(self.pairedDevices, deviceId)
    return true
end

function InputUser:unpairDevice(deviceId)
    for i = #self.pairedDevices, 1, -1 do
        if self.pairedDevices[i] == deviceId then
            table.remove(self.pairedDevices, i)
            return true
        end
    end
    return false
end

function InputUser:getPairedDevices()
    local devices = {}
    for _, deviceId in ipairs(self.pairedDevices) do
        local device = self.deviceManager:getDevice(deviceId)
        if device then
            table.insert(devices, device)
        end
    end
    return devices
end

function InputUser:clearPairedDevices()
    self.pairedDevices = {}
end

-- Event Registry Methods
function InputUser:onControlChanged(controlName, callback, object)
    if not self.eventRegistry[controlName] then
        self.eventRegistry[controlName] = {}
    end
    
    table.insert(self.eventRegistry[controlName], {
        callback = callback,
        object = object
    })
end

function InputUser:offControlChanged(controlName, callback, object)
    if not self.eventRegistry[controlName] then
        return
    end
    
    for i = #self.eventRegistry[controlName], 1, -1 do
        local listener = self.eventRegistry[controlName][i]
        if listener.callback == callback and listener.object == object then
            table.remove(self.eventRegistry[controlName], i)
        end
    end
end

function InputUser:checkControlStateChanges()
    for controlName, control in pairs(self.controls) do
        local currentState = {
            value = control:getValue(),
            pressed = control:isPressed(),
            released = control:isReleased(),
            down = control:isDown()
        }
        
        local lastState = self.lastControlStates[controlName]
        
        -- Check if state has changed
        local hasChanged = false
        if not lastState then
            hasChanged = true
        else
            if control.type == "vector" then
                hasChanged = lastState.value.x ~= currentState.value.x or 
                           lastState.value.y ~= currentState.value.y or
                           lastState.pressed ~= currentState.pressed or
                           lastState.released ~= currentState.released or
                           lastState.down ~= currentState.down
            else
                hasChanged = lastState.value ~= currentState.value or
                           lastState.pressed ~= currentState.pressed or
                           lastState.released ~= currentState.released or
                           lastState.down ~= currentState.down
            end
        end
        
        if hasChanged and self.eventRegistry[controlName] then
            -- Create callback context (similar to Unity's InputAction.CallbackContext)
            local context = {
                control = control,
                controlName = controlName,
                value = currentState.value,
                pressed = currentState.pressed,
                released = currentState.released,
                down = currentState.down,
                delta = control.type == "vector" and control:getDelta() or nil,
                lastValue = lastState and lastState.value or nil
            }
            
            -- Trigger callbacks
            for _, listener in ipairs(self.eventRegistry[controlName]) do
                if listener.object then
                    -- Object method call
                    listener.callback(listener.object, context)
                else
                    -- Solo function call
                    listener.callback(context)
                end
            end
        end
        
        -- Update last state
        self.lastControlStates[controlName] = currentState
    end
end

function InputUser:serialize()
    local data = {
        controlScheme = self.controlScheme:serialize(),
        pairedDevices = self.pairedDevices,
        enabled = self.enabled,
        userControls = {}
    }
    
    -- Serialize user's own controls
    for controlName, control in pairs(self.controls) do
        data.userControls[controlName] = {
            bindings = control.bindings,
            processors = control.processors
        }
    end
    
    return data
end

function InputUser:loadFromData(data)
    if data.controlScheme then
        self.controlScheme:loadFromData(data.controlScheme)
    end
    
    if data.pairedDevices then
        self.pairedDevices = data.pairedDevices
    end
    
    if data.enabled ~= nil then
        self.enabled = data.enabled
    end
    
    -- Load user's own controls
    if data.userControls then
        for controlName, controlData in pairs(data.userControls) do
            local control = self.controls[controlName]
            if control then
                if controlData.bindings then
                    control:rebind(controlData.bindings)
                end
                
                if controlData.processors then
                    -- Clear existing processors and add new ones
                    for _, processor in ipairs(controlData.processors) do
                        control:addProcessor(processor.name, unpack(processor.args or {}))
                    end
                end
            end
        end
    end
end

-- Input User Manager
local InputUserManager = {}
InputUserManager.__index = InputUserManager

function InputUserManager.new()
    local self = setmetatable({}, InputUserManager)
    
    self.users = {}
    self.deviceManager = DeviceSystem.DeviceManager.new()
    
    -- Wrap in proxy for safety
    local managerMethods = {
        createUser = true, removeUser = true, handleEvent = true, update = true,
        handleJoystickAdded = true, handleJoystickRemoved = true, getDeviceManager = true
    }
    
    return setmetatable(self, {
        __index = function(t, k)
            return InputUserManager[k] or rawget(t, k)
        end,
        __newindex = function(t, k, v)
            if managerMethods[k] then
                error(("Cannot override the %q method"):format(tostring(k)), 2)
            end
            rawset(t, k, v)
        end,
        __metatable = false,
        __tostring = function() return "InputUserManager" end
    })
end

function InputUserManager:createUser(controlScheme, pairedDevices)
    local user = InputUser.new(controlScheme, pairedDevices)
    table.insert(self.users, user)
    return user
end

function InputUserManager:removeUser(user)
    for i = #self.users, 1, -1 do
        if self.users[i] == user then
            table.remove(self.users, i)
            return true
        end
    end
    return false
end

function InputUserManager:handleEvent(eventType, ...)
    for _, user in ipairs(self.users) do
        user:handleEvent(eventType, ...)
    end
end

function InputUserManager:update()
    -- No longer needed for event-based system
    -- Keep for backward compatibility
end

function InputUserManager:handleJoystickAdded(joystick)
    self.deviceManager:handleJoystickAdded(joystick)
end

function InputUserManager:handleJoystickRemoved(joystick)
    self.deviceManager:handleJoystickRemoved(joystick)
end

function InputUserManager:getDeviceManager()
    return self.deviceManager
end

-- Wrap module export in proxy for safety
local module = {
    InputUser = InputUser,
    InputUserManager = InputUserManager
}

return setmetatable(module, {
    __index = function(_, k) 
        return module[k] 
    end,
    __newindex = function() 
        error("Cannot modify user module: it is read-only", 2)
    end,
    __metatable = false,
    __tostring = function() return "FLOOF user module" end
}) 