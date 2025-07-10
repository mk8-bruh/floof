local ControlSystem = require("input.control")
local DeviceSystem = require("input.devices")
local UserSystem = require("input.user")
local Config = require("input.config")
local Processors = require("input.processors")

local _rawInputSystem = {}

-- Global state
local userManager = nil
local controlSchemes = {}
local config = nil

-- Initialize the InputSystem
function _rawInputSystem.init()
    if not userManager then
        userManager = UserSystem.InputUserManager.new()
        config = Config.loadAndValidate()
        
        -- Load control schemes from config
        _rawInputSystem.loadControlSchemes()
        
        -- Create input users from config
        _rawInputSystem.loadInputUsers()
    end
    return _rawInputSystem
end

function _rawInputSystem.loadControlSchemes()
    if config.controlSchemes then
        for schemeName, schemeData in pairs(config.controlSchemes) do
            local scheme = ControlSystem.ControlScheme.new(schemeName)
            
            if schemeData.controls then
                for controlName, controlData in pairs(schemeData.controls) do
                    scheme:addControl(controlData)
                end
            end
            
            controlSchemes[schemeName] = scheme
        end
    end
end

function _rawInputSystem.loadInputUsers()
    if config.inputUsers then
        for userName, userData in pairs(config.inputUsers) do
            local controlScheme = controlSchemes[userData.controlScheme]
            if controlScheme then
                local user = userManager:createUser(controlScheme, userData.pairedDevices)
                if userData.enabled ~= nil then
                    user:setEnabled(userData.enabled)
                end
            end
        end
    end
end

function _rawInputSystem.createControlScheme(name, controls)
    local scheme = ControlSystem.ControlScheme.new(name, controls)
    controlSchemes[name] = scheme
    return scheme
end

function _rawInputSystem.getControlScheme(name)
    return controlSchemes[name]
end

function _rawInputSystem.createInputUser(controlScheme, pairedDevices)
    return userManager:createUser(controlScheme, pairedDevices)
end

function _rawInputSystem.removeInputUser(user)
    return userManager:removeUser(user)
end

function _rawInputSystem.getInputUser(index)
    return userManager.users[index]
end

function _rawInputSystem.getAllInputUsers()
    return userManager.users
end

function _rawInputSystem.handleEvent(eventType, ...)
    if userManager then
        userManager:handleEvent(eventType, ...)
    end
end

function _rawInputSystem.update()
    -- No longer needed for event-based system
    -- Keep for backward compatibility
end

function _rawInputSystem.handleJoystickAdded(joystick)
    if userManager then
        userManager:handleJoystickAdded(joystick)
    end
end

function _rawInputSystem.handleJoystickRemoved(joystick)
    if userManager then
        userManager:handleJoystickRemoved(joystick)
    end
end

function _rawInputSystem.getDeviceManager()
    return userManager and userManager:getDeviceManager()
end

function _rawInputSystem.saveConfig(filename)
    if not userManager then return false end
    
    local data = {
        controlSchemes = {},
        inputUsers = {}
    }
    
    -- Save modified control schemes
    for schemeName, scheme in pairs(controlSchemes) do
        local schemeData = scheme:serialize()
        if next(schemeData.controls) then -- Only save if there are modified controls
            data.controlSchemes[schemeName] = schemeData
        end
    end
    
    -- Save input users
    for i, user in ipairs(userManager.users) do
        data.inputUsers["user" .. i] = user:serialize()
    end
    
    return Config.save(data, filename)
end

function _rawInputSystem.loadConfig(filename)
    local newConfig = Config.loadAndValidate(filename)
    if newConfig then
        config = newConfig
        controlSchemes = {}
        userManager.users = {}
        
        _rawInputSystem.loadControlSchemes()
        _rawInputSystem.loadInputUsers()
        return true
    end
    return false
end

-- Convenience methods for quick access
function _rawInputSystem.getValue(userIndex, controlName)
    local user = _rawInputSystem.getInputUser(userIndex)
    return user and user:getValue(controlName) or 0
end

function _rawInputSystem.getDelta(userIndex, controlName)
    local user = _rawInputSystem.getInputUser(userIndex)
    return user and user:getDelta(controlName) or {x = 0, y = 0}
end

function _rawInputSystem.isPressed(userIndex, controlName)
    local user = _rawInputSystem.getInputUser(userIndex)
    return user and user:isPressed(controlName) or false
end

function _rawInputSystem.isReleased(userIndex, controlName)
    local user = _rawInputSystem.getInputUser(userIndex)
    return user and user:isReleased(controlName) or false
end

function _rawInputSystem.isDown(userIndex, controlName)
    local user = _rawInputSystem.getInputUser(userIndex)
    return user and user:isDown(controlName) or false
end

-- Expose processors for direct use
_rawInputSystem.processors = Processors

-- At the end, wrap _rawInputSystem in a proxy for safety
local inputSystem = setmetatable({}, {
    __index = function(_, k)
        return _rawInputSystem[k]
    end,
    __newindex = function(_, k, v)
        error("Cannot modify inputSystem: it is read-only", 2)
    end,
    __metatable = false,
    __tostring = function() return 'inputSystem' end
})

return inputSystem 