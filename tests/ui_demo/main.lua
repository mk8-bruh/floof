-- FLOOF UI Demo - Main Application
local floof = require("init")
local Object = require("object")

-- Load UI Classes
local Button = require("tests.ui_demo.classes.Button")
local Console = require("tests.ui_demo.classes.Console")
local Panel = require("tests.ui_demo.classes.Panel")
local Label = require("tests.ui_demo.classes.Label")

-- Main Application
local app = {}

function love.load()
    -- Set up the root object
    local root = Object()
    root.x, root.y = 0, 0
    root.w, root.h = love.graphics.getDimensions()
    Object.setRoot(root)
    
    -- Create main layout
    local mainPanel = Panel({
        x = 10, y = 10, 
        w = root.w - 320, h = root.h - 20,
        title = "Main Panel"
    })
    root:addChild(mainPanel)
    
    -- Create button grid
    local buttonPanel = Panel({
        x = 20, y = 50,
        w = mainPanel.w - 20, h = 200,
        title = "Button Grid"
    })
    mainPanel:addChild(buttonPanel)
    
    -- Add buttons in a grid
    local buttonData = {
        {text = "Button 1", color = {0.2, 0.6, 1.0, 1.0}},
        {text = "Button 2", color = {0.6, 0.2, 1.0, 1.0}},
        {text = "Button 3", color = {1.0, 0.2, 0.6, 1.0}},
        {text = "Button 4", color = {0.2, 1.0, 0.6, 1.0}},
        {text = "Button 5", color = {1.0, 0.6, 0.2, 1.0}},
        {text = "Button 6", color = {0.6, 1.0, 0.2, 1.0}},
    }
    
    for i, data in ipairs(buttonData) do
        local row = math.floor((i-1) / 3)
        local col = (i-1) % 3
        local button = Button({
            x = 20 + col * 120, y = 40 + row * 50,
            w = 100, h = 35,
            text = data.text,
            color = data.color
        })
        buttonPanel:addChild(button)
    end
    
    -- Create side panel
    local sidePanel = Panel({
        x = mainPanel.w + 20, y = 10,
        w = 300, h = root.h - 20,
        title = "Side Panel"
    })
    root:addChild(sidePanel)
    
    -- Add console
    local console = Console({
        x = 10, y = 50,
        w = sidePanel.w - 20, h = sidePanel.h - 100,
        maxLines = 50
    })
    sidePanel:addChild(console)
    
    -- Add some side buttons
    local sideButton1 = Button({
        x = 10, y = sidePanel.h - 80,
        w = 130, h = 30,
        text = "Clear Console",
        color = {0.8, 0.2, 0.2, 1.0}
    })
    sidePanel:addChild(sideButton1)
    
    local sideButton2 = Button({
        x = 150, y = sidePanel.h - 80,
        w = 130, h = 30,
        text = "Add Log",
        color = {0.2, 0.8, 0.2, 1.0}
    })
    sidePanel:addChild(sideButton2)
    
    -- Add info label
    local infoLabel = Label({
        x = 10, y = sidePanel.h - 40,
        w = 280, h = 20,
        text = "Resize window to test responsive layout!",
        color = {0.8, 0.8, 0.8, 1}
    })
    sidePanel:addChild(infoLabel)
    
    -- Set up message handling
    root:send("buttonPressed", function(self, buttonText)
        console:addLine("Button pressed: " .. buttonText)
    end)
    
    -- Special button handlers
    sideButton1:send("buttonPressed", function(self, buttonText)
        console.lines:clear()
        console.scrollY = 0
        console:addLine("Console cleared!")
    end)
    
    sideButton2:send("buttonPressed", function(self, buttonText)
        console:addLine("Manual log entry at " .. os.date("%H:%M:%S"))
    end)
    
    -- Store references
    app.root = root
    app.console = console
    app.mainPanel = mainPanel
    app.sidePanel = sidePanel
    
    -- Initial log
    console:addLine("FLOOF UI Demo started!")
    console:addLine("Click buttons to see interactions")
    console:addLine("Scroll console with mouse wheel")

    floof()
end

function love.update(dt)
    app.root:update(dt)
end

function love.draw()
    app.root:draw()
end

function love.resize(w, h)
    app.root:resize(w, h)
    
    -- Update layout for responsive design
    app.mainPanel.w = w - 320
    app.mainPanel.h = h - 20
    
    app.sidePanel.x = app.mainPanel.w + 20
    app.sidePanel.h = h - 20
    
    app.console.w = app.sidePanel.w - 20
    app.console.h = app.sidePanel.h - 100
    
    -- Update button positions in side panel
    local sideButton1 = app.sidePanel.children[2] -- Console is first child
    local sideButton2 = app.sidePanel.children[3]
    local infoLabel = app.sidePanel.children[4]
    
    if sideButton1 and sideButton2 and infoLabel then
        sideButton1.y = app.sidePanel.h - 80
        sideButton2.y = app.sidePanel.h - 80
        infoLabel.y = app.sidePanel.h - 40
    end
end

-- Forward all LÖVE callbacks to the root object
local callbacks = {
    "keypressed", "keyreleased", "textinput", "mousepressed", "mousereleased",
    "mousemoved", "wheelmoved", "touchpressed", "touchreleased", "touchmoved",
    "gamepadpressed", "gamepadreleased", "gamepadaxis", "joystickpressed",
    "joystickreleased", "joystickaxis", "joystickhat", "joystickball",
    "filedropped", "directorydropped", "lowmemory", "threaderror"
}

for _, callback in ipairs(callbacks) do
    love[callback] = function(...)
        if app.root then
            app.root[callback](app.root, ...)
        end
    end
end 