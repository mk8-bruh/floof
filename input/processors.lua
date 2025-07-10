local Processors = {}

-- Deadzone processor - removes small input values
function Processors.deadzone(value, threshold)
    if type(value) == "table" then
        local result = {x = value.x, y = value.y}
        local magnitude = math.sqrt(value.x * value.x + value.y * value.y)
        
        if magnitude < threshold then
            result.x = 0
            result.y = 0
        else
            local scale = (magnitude - threshold) / (1 - threshold)
            result.x = (value.x / magnitude) * scale
            result.y = (value.y / magnitude) * scale
        end
        
        return result
    else
        if math.abs(value) < threshold then
            return 0
        else
            local sign = value > 0 and 1 or -1
            return sign * (math.abs(value) - threshold) / (1 - threshold)
        end
    end
end

-- Scale processor - multiplies input by a factor
function Processors.scale(value, factor)
    if type(value) == "table" then
        return {x = value.x * factor, y = value.y * factor}
    else
        return value * factor
    end
end

-- Clamp processor - limits input to a range
function Processors.clamp(value, min, max)
    if type(value) == "table" then
        return {
            x = math.max(min, math.min(max, value.x)),
            y = math.max(min, math.min(max, value.y))
        }
    else
        return math.max(min, math.min(max, value))
    end
end

-- Normalize processor - scales vector to unit length
function Processors.normalize(value)
    if type(value) == "table" then
        local magnitude = math.sqrt(value.x * value.x + value.y * value.y)
        if magnitude > 0 then
            return {x = value.x / magnitude, y = value.y / magnitude}
        else
            return {x = 0, y = 0}
        end
    else
        if value > 0 then
            return 1
        elseif value < 0 then
            return -1
        else
            return 0
        end
    end
end

-- Smooth processor - applies smoothing to input
function Processors.smooth(value, smoothing, lastValue)
    if type(value) == "table" then
        return {
            x = value.x * (1 - smoothing) + (lastValue and lastValue.x or 0) * smoothing,
            y = value.y * (1 - smoothing) + (lastValue and lastValue.y or 0) * smoothing
        }
    else
        return value * (1 - smoothing) + (lastValue or 0) * smoothing
    end
end

-- Invert processor - inverts input values
function Processors.invert(value)
    if type(value) == "table" then
        return {x = -value.x, y = -value.y}
    else
        return -value
    end
end

-- Threshold processor - converts continuous input to discrete
function Processors.threshold(value, threshold)
    if type(value) == "table" then
        local magnitude = math.sqrt(value.x * value.x + value.y * value.y)
        if magnitude > threshold then
            return Processors.normalize(value)
        else
            return {x = 0, y = 0}
        end
    else
        if math.abs(value) > threshold then
            return value > 0 and 1 or -1
        else
            return 0
        end
    end
end

-- Curve processor - applies a curve to input values
function Processors.curve(value, curveType, intensity)
    intensity = intensity or 1
    
    if type(value) == "table" then
        local magnitude = math.sqrt(value.x * value.x + value.y * value.y)
        local direction = {x = value.x / magnitude, y = value.y / magnitude}
        
        local curvedMagnitude = Processors.curve(magnitude, curveType, intensity)
        
        return {
            x = direction.x * curvedMagnitude,
            y = direction.y * curvedMagnitude
        }
    else
        local absValue = math.abs(value)
        local sign = value > 0 and 1 or -1
        
        if curveType == "exponential" then
            return sign * (absValue ^ intensity)
        elseif curveType == "logarithmic" then
            return sign * (1 - math.log(1 + (1 - absValue) * intensity))
        elseif curveType == "sine" then
            return sign * math.sin(absValue * math.pi / 2) ^ intensity
        elseif curveType == "quadratic" then
            return sign * (absValue * absValue)
        elseif curveType == "cubic" then
            return sign * (absValue * absValue * absValue)
        else
            return value
        end
    end
end

-- Combine processor - combines multiple inputs
function Processors.combine(inputs, combineType)
    combineType = combineType or "add"
    
    if #inputs == 0 then
        return type(inputs[1]) == "table" and {x = 0, y = 0} or 0
    end
    
    if combineType == "add" then
        local result = type(inputs[1]) == "table" and {x = 0, y = 0} or 0
        for _, input in ipairs(inputs) do
            if type(input) == "table" then
                result.x = result.x + input.x
                result.y = result.y + input.y
            else
                result = result + input
            end
        end
        return result
    elseif combineType == "multiply" then
        local result = type(inputs[1]) == "table" and {x = 1, y = 1} or 1
        for _, input in ipairs(inputs) do
            if type(input) == "table" then
                result.x = result.x * input.x
                result.y = result.y * input.y
            else
                result = result * input
            end
        end
        return result
    elseif combineType == "max" then
        local result = inputs[1]
        for i = 2, #inputs do
            local input = inputs[i]
            if type(input) == "table" then
                local mag1 = math.sqrt(result.x * result.x + result.y * result.y)
                local mag2 = math.sqrt(input.x * input.x + input.y * input.y)
                if mag2 > mag1 then
                    result = input
                end
            else
                if math.abs(input) > math.abs(result) then
                    result = input
                end
            end
        end
        return result
    end
    
    return inputs[1]
end

-- Conditional processor - applies processing based on conditions
function Processors.conditional(value, condition, trueProcessor, falseProcessor)
    if condition then
        return trueProcessor and trueProcessor(value) or value
    else
        return falseProcessor and falseProcessor(value) or value
    end
end

-- Wrap module export in proxy for safety
return setmetatable(Processors, {
    __index = function(_, k) 
        return Processors[k] 
    end,
    __newindex = function() 
        error("Cannot modify processors module: it is read-only", 2)
    end,
    __metatable = false,
    __tostring = function() return "FLOOF processors module" end
}) 