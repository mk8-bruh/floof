-- Input System Demo for FLOOF
-- Demonstrates the flexible input binding system

local floof = require("floof")
local Input = require("input")

-- Initialize FLOOF
floof.init()

-- Create a player object
local Player = floof.Class("Player")

function Player:init()
    self.x = 400
    self.y = 300
    self.speed = 200
    self.size = 30
    self.color = {1, 1, 1}
    
    -- Add input component
    self:addComponent(floof.InputComponent())
    
    -- Load default configuration
    self.input:loadConfig("input_config.yaml")
    
    -- Add processors for smooth movement
    self.input:addProcessor("movement", "horizontal", "deadzone", 0.1)
    self.input:addProcessor("movement", "vertical", "deadzone", 0.1)
    self.input:addProcessor("movement", "horizontal", "scale", 2.0)
    self.input:addProcessor("movement", "vertical", "scale", 2.0)
end

function Player:update(dt)
    -- Get movement input
    local moveX = self.input:getProcessed("movement", "horizontal") or 0
    local moveY = self.input:getProcessed("movement", "vertical") or 0
    
    -- Apply movement
    self.x = self.x + moveX * self.speed * dt
    self.y = self.y + moveY * self.speed * dt
    
    -- Keep player on screen
    self.x = math.max(self.size, math.min(800 - self.size, self.x))
    self.y = math.max(self.size, math.min(600 - self.size, self.y))
    
    -- Handle actions
    if self.input:isPressed("actions", "jump") then
        self.color = {1, 0, 0} -- Red when jumping
    elseif self.input:isPressed("actions", "attack") then
        self.color = {0, 1, 0} -- Green when attacking
    else
        self.color = {1, 1, 1} -- White normally
    end
    
    -- Handle camera input
    local lookDelta = self.input:getProcessedDelta("camera", "look")
    if lookDelta then
        -- Apply some camera effect (just change player color for demo)
        self.color = {
            math.min(1, self.color[1] + lookDelta.x * 0.01),
            math.min(1, self.color[2] + lookDelta.y * 0.01),
            self.color[3]
        }
    end
end

function Player:draw()
    love.graphics.setColor(self.color)
    love.graphics.circle("fill", self.x, self.y, self.size)
    love.graphics.setColor(0, 0, 0)
    love.graphics.circle("line", self.x, self.y, self.size)
end

-- Create a UI object for touch input demo
local TouchUI = floof.Class("TouchUI")

function TouchUI:init()
    self.x = 100
    self.y = 100
    self.width = 200
    self.height = 100
    self.touchX = 0
    self.touchY = 0
    self.isTouched = false
    
    -- Add input component
    self:addComponent(floof.InputComponent())
    
    -- Add touch input relative to this object
    self.input:addObjectTouchInput("touch", "position", self)
    self.input:addObjectTouchDeltaInput("touch", "delta", self)
end

function TouchUI:update(dt)
    -- Get touch input
    local touchPos = self.input:get("touch", "position")
    local touchDelta = self.input:getDelta("touch", "delta")
    
    if touchPos then
        self.touchX = touchPos.x
        self.touchY = touchPos.y
        self.isTouched = true
    else
        self.isTouched = false
    end
    
    -- Apply touch delta to move the UI element
    if touchDelta then
        self.x = self.x + touchDelta.x
        self.y = self.y + touchDelta.y
    end
end

function TouchUI:draw()
    if self.isTouched then
        love.graphics.setColor(0, 1, 1)
    else
        love.graphics.setColor(0.5, 0.5, 0.5)
    end
    
    love.graphics.rectangle("fill", self.x, self.y, self.width, self.height)
    love.graphics.setColor(0, 0, 0)
    love.graphics.rectangle("line", self.x, self.y, self.width, self.height)
    
    -- Draw touch indicator
    if self.isTouched then
        love.graphics.setColor(1, 0, 0)
        love.graphics.circle("fill", self.x + self.touchX, self.y + self.touchY, 10)
    end
end

-- Create a processor demo object
local ProcessorDemo = floof.Class("ProcessorDemo")

function ProcessorDemo:init()
    self.x = 600
    self.y = 100
    self.width = 150
    self.height = 150
    self.rawValue = 0
    self.processedValue = 0
    
    -- Add input component
    self:addComponent(floof.InputComponent())
    
    -- Create a custom axis input for demo
    local InputTypes = require("input.types")
    local axis = InputTypes.Axis.new({
        {type = "key_negative", value = "q"},
        {type = "key_positive", value = "e"}
    })
    
    if not self.input.inputSystem.schemes["demo"] then
        self.input.inputSystem.schemes["demo"] = {}
    end
    if not self.input.inputSystem.schemes["demo"]["processor"] then
        self.input.inputSystem.schemes["demo"]["processor"] = {}
    end
    
    self.input.inputSystem.schemes["demo"]["processor"]["test"] = axis
    self.input:setScheme("demo")
    
    -- Add various processors
    self.input:addProcessor("processor", "test", "deadzone", 0.2)
    self.input:addProcessor("processor", "test", "curve", "exponential", 2)
    self.input:addProcessor("processor", "test", "scale", 0.5)
end

function ProcessorDemo:update(dt)
    self.rawValue = self.input:get("processor", "test") or 0
    self.processedValue = self.input:getProcessed("processor", "test") or 0
end

function ProcessorDemo:draw()
    love.graphics.setColor(0.8, 0.8, 0.8)
    love.graphics.rectangle("fill", self.x, self.y, self.width, self.height)
    love.graphics.setColor(0, 0, 0)
    love.graphics.rectangle("line", self.x, self.y, self.width, self.height)
    
    -- Draw raw value
    love.graphics.setColor(1, 0, 0)
    local rawBarWidth = (self.rawValue + 1) * self.width / 2
    love.graphics.rectangle("fill", self.x + self.width/2, self.y + 30, rawBarWidth, 20)
    
    -- Draw processed value
    love.graphics.setColor(0, 1, 0)
    local processedBarWidth = (self.processedValue + 1) * self.width / 2
    love.graphics.rectangle("fill", self.x + self.width/2, self.y + 60, processedBarWidth, 20)
    
    -- Draw labels
    love.graphics.setColor(0, 0, 0)
    love.graphics.print("Raw: " .. string.format("%.2f", self.rawValue), self.x + 10, self.y + 10)
    love.graphics.print("Processed: " .. string.format("%.2f", self.processedValue), self.x + 10, self.y + 40)
    love.graphics.print("Press Q/E to test", self.x + 10, self.y + 80)
end

-- Create objects
local player = Player()
local touchUI = TouchUI()
local processorDemo = ProcessorDemo()

-- Add objects to root
floof.root:addChild(player)
floof.root:addChild(touchUI)
floof.root:addChild(processorDemo)

-- LOVE2D callbacks
function love.load()
    love.window.setMode(800, 600)
    love.graphics.setBackgroundColor(0.2, 0.2, 0.2)
end

function love.update(dt)
    floof.root:update(dt)
    Input.update()
end

function love.draw()
    floof.root:draw()
    
    -- Draw instructions
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("WASD/Arrow Keys: Move Player", 10, 10)
    love.graphics.print("Space/W/Up: Jump (Red)", 10, 25)
    love.graphics.print("J/Mouse1: Attack (Green)", 10, 40)
    love.graphics.print("Mouse: Camera Look", 10, 55)
    love.graphics.print("Touch: Move UI Element (Cyan)", 10, 70)
    love.graphics.print("Q/E: Test Processors", 10, 85)
    love.graphics.print("F1: Save Config, F2: Load Config", 10, 100)
end

function love.keypressed(key)
    if key == "f1" then
        -- Save current configuration
        if Input.saveConfig("custom_input_config.yaml") then
            print("Configuration saved!")
        else
            print("Failed to save configuration")
        end
    elseif key == "f2" then
        -- Load configuration
        if Input.loadConfig("custom_input_config.yaml") then
            print("Configuration loaded!")
        else
            print("Failed to load configuration")
        end
    elseif key == "escape" then
        love.event.quit()
    end
end

function love.joystickadded(joystick)
    print("Joystick connected:", joystick:getName())
    Input.getSystem():refreshJoysticks()
end

function love.joystickremoved(joystick)
    print("Joystick disconnected:", joystick:getName())
    Input.getSystem():refreshJoysticks()
end 