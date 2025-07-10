local Devices = {}

-- Device types
Devices.TYPES = {
    KEYBOARD = "keyboard",
    MOUSE = "mouse",
    JOYSTICK = "joystick",
    GAMEPAD = "gamepad"
}

-- Device class
local Device = {}
Device.__index = Device

function Device.new(deviceType, id, name)
    local self = setmetatable({}, Device)
    
    self.type = deviceType
    self.id = id
    self.name = name or ("Device_" .. deviceType .. "_" .. id)
    self.connected = true
    self.enabled = true
    
    -- Wrap in proxy for safety
    local deviceMethods = {
        isConnected = true, isEnabled = true, setEnabled = true, disconnect = true, connect = true
    }
    
    return setmetatable(self, {
        __index = function(t, k)
            return Device[k] or rawget(t, k)
        end,
        __newindex = function(t, k, v)
            if deviceMethods[k] then
                error(("Cannot override the %q method"):format(tostring(k)), 2)
            end
            rawset(t, k, v)
        end,
        __metatable = false,
        __tostring = function() return ("Device: %s"):format(self.name) end
    })
end

function Device:isConnected()
    return self.connected
end

function Device:isEnabled()
    return self.enabled and self.connected
end

function Device:setEnabled(enabled)
    self.enabled = enabled
end

function Device:disconnect()
    self.connected = false
end

function Device:connect()
    self.connected = true
end

-- Device Manager
local DeviceManager = {}
DeviceManager.__index = DeviceManager

function DeviceManager.new()
    local self = setmetatable({}, DeviceManager)
    
    self.devices = {}
    self.deviceTypes = {}
    
    -- Initialize device type tables
    for _, deviceType in pairs(Devices.TYPES) do
        self.deviceTypes[deviceType] = {}
    end
    
    -- Auto-detect devices
    self:refreshDevices()
    
    -- Wrap in proxy for safety
    local managerMethods = {
        refreshDevices = true, addDevice = true, removeDevice = true, getDevice = true,
        getDevices = true, getConnectedDevices = true, refreshJoysticks = true,
        handleJoystickAdded = true, handleJoystickRemoved = true, validateBinding = true,
        getJoystickForBinding = true
    }
    
    return setmetatable(self, {
        __index = function(t, k)
            return DeviceManager[k] or rawget(t, k)
        end,
        __newindex = function(t, k, v)
            if managerMethods[k] then
                error(("Cannot override the %q method"):format(tostring(k)), 2)
            end
            rawset(t, k, v)
        end,
        __metatable = false,
        __tostring = function() return "DeviceManager" end
    })
end

function DeviceManager:refreshDevices()
    -- Refresh joysticks/gamepads
    self:refreshJoysticks()
    
    -- Ensure keyboard and mouse are always available
    if not self.deviceTypes[Devices.TYPES.KEYBOARD][1] then
        self:addDevice(Devices.TYPES.KEYBOARD, 1, "Keyboard")
    end
    
    if not self.deviceTypes[Devices.TYPES.MOUSE][1] then
        self:addDevice(Devices.TYPES.MOUSE, 1, "Mouse")
    end
end

function DeviceManager:addDevice(deviceType, id, name)
    local device = Device.new(deviceType, id, name)
    self.devices[deviceType .. "_" .. id] = device
    self.deviceTypes[deviceType][id] = device
    return device
end

function DeviceManager:removeDevice(deviceType, id)
    local deviceKey = deviceType .. "_" .. id
    local device = self.devices[deviceKey]
    if device then
        device:disconnect()
        self.devices[deviceKey] = nil
        self.deviceTypes[deviceType][id] = nil
    end
end

function DeviceManager:getDevice(deviceType, id)
    return self.deviceTypes[deviceType] and self.deviceTypes[deviceType][id]
end

function DeviceManager:getDevices(deviceType)
    if not deviceType then
        return self.devices
    end
    return self.deviceTypes[deviceType] or {}
end

function DeviceManager:getConnectedDevices(deviceType)
    local devices = {}
    local deviceList = deviceType and self.deviceTypes[deviceType] or self.devices
    
    for _, device in pairs(deviceList) do
        if device:isConnected() then
            table.insert(devices, device)
        end
    end
    
    return devices
end

function DeviceManager:refreshJoysticks()
    -- Remove disconnected joysticks
    for id, device in pairs(self.deviceTypes[Devices.TYPES.JOYSTICK]) do
        local found = false
        for i = 1, love.joystick.getJoystickCount() do
            local joystick = love.joystick.getJoystick(i)
            if joystick and joystick:getID() == id then
                found = true
                break
            end
        end
        if not found then
            self:removeDevice(Devices.TYPES.JOYSTICK, id)
        end
    end
    
    -- Add new joysticks
    for i = 1, love.joystick.getJoystickCount() do
        local joystick = love.joystick.getJoystick(i)
        if joystick then
            local id = joystick:getID()
            local name = joystick:getName()
            
            if not self.deviceTypes[Devices.TYPES.JOYSTICK][id] then
                self:addDevice(Devices.TYPES.JOYSTICK, id, name)
            end
        end
    end
end

function DeviceManager:handleJoystickAdded(joystick)
    local id = joystick:getID()
    local name = joystick:getName()
    
    if not self.deviceTypes[Devices.TYPES.JOYSTICK][id] then
        self:addDevice(Devices.TYPES.JOYSTICK, id, name)
    end
end

function DeviceManager:handleJoystickRemoved(joystick)
    local id = joystick:getID()
    self:removeDevice(Devices.TYPES.JOYSTICK, id)
end

-- Binding validation
function DeviceManager:validateBinding(binding)
    if not binding.type then
        return false, "Binding missing type"
    end
    
    if binding.type == "key" then
        -- Keyboard keys are always valid
        return true
    elseif binding.type == "mouse" then
        -- Mouse buttons are always valid
        return true
    elseif binding.type == "joystick" then
        if not binding.joystickId then
            return false, "Joystick binding missing joystickId"
        end
        local device = self:getDevice(Devices.TYPES.JOYSTICK, binding.joystickId)
        if not device or not device:isConnected() then
            return false, "Joystick device not found or disconnected"
        end
        return true
    elseif binding.type == "joystick_positive" or binding.type == "joystick_negative" then
        if not binding.joystickId then
            return false, "Joystick button binding missing joystickId"
        end
        local device = self:getDevice(Devices.TYPES.JOYSTICK, binding.joystickId)
        if not device or not device:isConnected() then
            return false, "Joystick device not found or disconnected"
        end
        return true
    elseif binding.type == "axis_composite" then
        if not binding.x_joystickId or not binding.y_joystickId then
            return false, "Axis composite binding missing joystick IDs"
        end
        local xDevice = self:getDevice(Devices.TYPES.JOYSTICK, binding.x_joystickId)
        local yDevice = self:getDevice(Devices.TYPES.JOYSTICK, binding.y_joystickId)
        if not xDevice or not xDevice:isConnected() then
            return false, "X-axis joystick device not found or disconnected"
        end
        if not yDevice or not yDevice:isConnected() then
            return false, "Y-axis joystick device not found or disconnected"
        end
        return true
    end
    
    return false, "Unknown binding type: " .. binding.type
end

-- Get actual joystick object for binding
function DeviceManager:getJoystickForBinding(binding)
    if binding.joystickId then
        for i = 1, love.joystick.getJoystickCount() do
            local joystick = love.joystick.getJoystick(i)
            if joystick and joystick:getID() == binding.joystickId then
                return joystick
            end
        end
    end
    return nil
end

-- Wrap module export in proxy for safety
local module = {
    Device = Device,
    DeviceManager = DeviceManager,
    TYPES = Devices.TYPES
}

return setmetatable(module, {
    __index = function(_, k) 
        return module[k] 
    end,
    __newindex = function() 
        error("Cannot modify devices module: it is read-only", 2)
    end,
    __metatable = false,
    __tostring = function() return "FLOOF devices module" end
}) 