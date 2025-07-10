local Config = {}

-- Simple YAML-like serializer
local function serializeYAML(data, indent)
    indent = indent or 0
    local spaces = string.rep("  ", indent)
    local result = ""
    
    if type(data) == "table" then
        for key, value in pairs(data) do
            if type(value) == "table" then
                result = result .. spaces .. key .. ":\n"
                result = result .. serializeYAML(value, indent + 1)
            else
                if type(value) == "string" then
                    result = result .. spaces .. key .. ": \"" .. value .. "\"\n"
                else
                    result = result .. spaces .. key .. ": " .. tostring(value) .. "\n"
                end
            end
        end
    end
    
    return result
end

-- Simple YAML-like deserializer
local function deserializeYAML(content)
    local data = {}
    local stack = {data}
    local indentStack = {0}
    
    for line in content:gmatch("[^\r\n]+") do
        line = line:match("^%s*(.-)%s*$") -- trim whitespace
        
        if line ~= "" and not line:match("^#") then -- skip empty lines and comments
            local indent = 0
            while line:sub(indent + 1, indent + 1) == " " do
                indent = indent + 1
            end
            indent = indent / 2 -- assuming 2 spaces per indent level
            
            -- Find the appropriate parent level
            while #indentStack > 1 and indent <= indentStack[#indentStack - 1] do
                table.remove(stack)
                table.remove(indentStack)
            end
            
            local key, value = line:match("^([^:]+):%s*(.*)$")
            if key then
                key = key:match("^%s*(.-)%s*$") -- trim whitespace
                
                if value == "" then
                    -- Start a new table
                    stack[#stack][key] = {}
                    table.insert(stack, stack[#stack][key])
                    table.insert(indentStack, indent)
                else
                    -- Simple value
                    if value:match("^\"(.*)\"$") then
                        -- String value
                        value = value:match("^\"(.*)\"$")
                    elseif value == "true" then
                        value = true
                    elseif value == "false" then
                        value = false
                    elseif tonumber(value) then
                        value = tonumber(value)
                    end
                    stack[#stack][key] = value
                end
            end
        end
    end
    
    return data
end

-- Save configuration to file
function Config.save(data, filename)
    filename = filename or "input_config.yaml"
    
    local content = serializeYAML(data)
    local file = io.open(filename, "w")
    if file then
        file:write(content)
        file:close()
        return true
    end
    return false
end

-- Load configuration from file
function Config.load(filename)
    filename = filename or "input_config.yaml"
    
    local file = io.open(filename, "r")
    if file then
        local content = file:read("*all")
        file:close()
        
        -- Silently handle parsing errors
        local success, data = pcall(deserializeYAML, content)
        if success then
            return data
        else
            print("Warning: Failed to parse config file: " .. filename)
            return nil
        end
    end
    return nil
end

-- Validate configuration structure
function Config.validate(data)
    if type(data) ~= "table" then
        return false, "Config must be a table"
    end
    
    -- Validate control schemes
    if data.controlSchemes then
        for schemeName, scheme in pairs(data.controlSchemes) do
            if type(scheme) ~= "table" then
                return false, "Control scheme '" .. schemeName .. "' must be a table"
            end
            
            if scheme.controls then
                for controlName, control in pairs(scheme.controls) do
                    if type(control) ~= "table" then
                        return false, "Control '" .. controlName .. "' in scheme '" .. schemeName .. "' must be a table"
                    end
                    
                    -- Validate control structure
                    if not control.type then
                        return false, "Control '" .. controlName .. "' missing 'type' field"
                    end
                    
                    if control.type ~= "button" and control.type ~= "axis" and control.type ~= "vector" then
                        return false, "Invalid control type '" .. control.type .. "' for control '" .. controlName .. "'"
                    end
                    
                    if control.bindings and type(control.bindings) ~= "table" then
                        return false, "Control '" .. controlName .. "' bindings must be a table"
                    end
                end
            end
        end
    end
    
    -- Validate input users
    if data.inputUsers then
        for userName, user in pairs(data.inputUsers) do
            if type(user) ~= "table" then
                return false, "Input user '" .. userName .. "' must be a table"
            end
            
            if user.controlScheme and type(user.controlScheme) ~= "string" then
                return false, "Input user '" .. userName .. "' controlScheme must be a string"
            end
            
            if user.pairedDevices and type(user.pairedDevices) ~= "table" then
                return false, "Input user '" .. userName .. "' pairedDevices must be a table"
            end
        end
    end
    
    return true
end

-- Create default configuration
function Config.createDefault()
    return {
        controlSchemes = {
            default = {
                controls = {
                    movement = {
                        name = "movement",
                        type = "vector",
                        bindings = {
                            {
                                type = "key_negative",
                                value = "a"
                            },
                            {
                                type = "key_positive",
                                value = "d"
                            },
                            {
                                type = "key_negative",
                                value = "w"
                            },
                            {
                                type = "key_positive",
                                value = "s"
                            }
                        }
                    },
                    jump = {
                        name = "jump",
                        type = "button",
                        bindings = {
                            {
                                type = "key",
                                value = "space"
                            }
                        }
                    },
                    attack = {
                        name = "attack",
                        type = "button",
                        bindings = {
                            {
                                type = "key",
                                value = "j"
                            },
                            {
                                type = "mouse",
                                value = 1
                            }
                        }
                    },
                    look = {
                        name = "look",
                        type = "vector",
                        bindings = {
                            {
                                type = "mouse_delta"
                            }
                        }
                    }
                }
            }
        },
        inputUsers = {
            player1 = {
                controlScheme = "default",
                pairedDevices = {},
                enabled = true
            }
        }
    }
end

-- Merge configurations (custom overrides defaults)
function Config.merge(defaultConfig, customConfig)
    if not customConfig then
        return defaultConfig
    end
    
    local merged = {}
    
    -- Copy default config
    for key, value in pairs(defaultConfig) do
        if type(value) == "table" then
            merged[key] = {}
            for subKey, subValue in pairs(value) do
                merged[key][subKey] = subValue
            end
        else
            merged[key] = value
        end
    end
    
    -- Override with custom config
    for key, value in pairs(customConfig) do
        if type(value) == "table" and merged[key] and type(merged[key]) == "table" then
            for subKey, subValue in pairs(value) do
                merged[key][subKey] = subValue
            end
        else
            merged[key] = value
        end
    end
    
    return merged
end

-- Load and validate configuration
function Config.loadAndValidate(filename)
    local customConfig = Config.load(filename)
    local defaultConfig = Config.createDefault()
    
    if customConfig then
        local valid, error = Config.validate(customConfig)
        if not valid then
            print("Warning: Invalid config file: " .. error)
            return defaultConfig
        end
        
        return Config.merge(defaultConfig, customConfig)
    end
    
    return defaultConfig
end

-- Wrap module export in proxy for safety
return setmetatable(Config, {
    __index = function(_, k) 
        return Config[k] 
    end,
    __newindex = function() 
        error("Cannot modify config module: it is read-only", 2)
    end,
    __metatable = false,
    __tostring = function() return "FLOOF config module" end
}) 