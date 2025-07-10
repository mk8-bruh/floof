# FLOOF

***F**ast **L**ua **O**bject-**O**riented **F**ramework*

A lightweight and intuitive object system for LOVE2D, inspired by Unity's MonoBehaviour model.

FLOOF helps you build your game using clean, modular Lua code. With built-in support for hierarchy, automatic callback routing, and flexible class-based logic, it makes structuring your game world feel natural and smooth.

---

## ✨ Features

👨‍👧‍👦 **OBJECT hierarchy** — nest objects with parent-child relationships and automatic transform inheritance

🧠 **CLASS system** — define reusable behaviors and extendable object types using pure Lua

🧩 **Mixins support** through INDEXES — compose shared functionality into multiple classes

🔄 **LOVE2D Integration** — automatically route LOVE's update, draw, and other lifecycle callbacks to objects

🎯 **Hitbox detection** — built-in collision detection for UI interaction and game logic

📦 **Array utilities** — enhanced array implementation with useful methods

🧼 **Clean & independent** — pure Lua, zero external dependencies

🎮 **Advanced Input System** — flexible input handling with processors and configuration for games

---

## 📦 Installation

```bash
git clone https://github.com/mk8-bruh/floof
```

Place the `floof/` directory in your project, and require the main module:

```lua
floof = require "floof"
```

FLOOF has no dependencies beyond LOVE2D and Lua 5.1+

## 🏗️ Architecture

FLOOF is organized into focused modules for better maintainability:

- **`core/object.lua`** - Object creation and hierarchy management
- **`core/class.lua`** - Class system and inheritance
- **`input/`** - Advanced input system with processors and configuration
- **`core/hitbox.lua`** - Hitbox detection functions for UI interaction
- **`core/array.lua`** - Enhanced array utilities

For detailed architecture information, see [STRUCTURE.md](STRUCTURE.md).

---

## 🚀 Quick Start

```lua
-- main.lua
floof = require "floof"

World = floof.class("World")

Entity = floof.class("Entity")

function Entity:init(world, x, y, w, h, weight)
    self.parent = world
    self.x, self.y, self.w, self.h = x, y, w, h
    self.weight = weight or 1

    self.px, self.py = x, y
end

function Entity:draw()
    love.graphics.setColor(1, 1, 1)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", self.x, self.y, self.w, self.h)
end

Player = floof.class("Player", Entity)

function Player:init(world, x, y, moveSpeed)
    self.moveSpeed = moveSpeed
    self.super.init(self, world, x, y, 100, 100)
end

function Player:update(dt)
    self.x = self.x + self.horizontalInput * self.moveSpeed * dt
    self.y = self.y + self.verticalInput   * self.moveSpeed * dt
end

function Player:draw()
    love.graphics.setColor(1, 0, 0)
    love.graphics.rectangle("fill", self.x, self.y, self.w, self.h)
end

function love.load()
    world = World()
    player = Player(world, 0, 0)

    floof.init() -- hook into LOVE2D callbacks
end
```

---

## 🧱 Core Concepts

### 🧸 Objects

The basic building block of the FLOOF hierarchy is an `object`. Objects can be nested to create complex hierarchies with automatic callback routing.

#### Creating Objects

```lua
-- Basic object creation
local obj = floof.new({name = "my_object"})

-- Object with properties
local rect = floof.new({
    name = "rectangle",
    x = 100, y = 100, w = 50, h = 50,
    check = floof.checks.cornerRect
})
```

#### Object Hierarchy

You can nest objects to create hierarchies:

```lua
local parent = floof.new{name = "parent"}
local child1 = floof.new{name = "child1"}
local child2 = floof.new{name = "child2"}

-- Set parent-child relationships
child1.parent = parent
child2.parent = parent

-- Or use the children property
parent.children = {child1, child2}

-- Or use convenience methods
parent:addChild(child1)
parent:addChild(child2)

-- Remove children
parent:removeChild(child1)



-- Set parent with method chaining
child1:setParent(parent):setParent(nil)  -- Add then remove
```

This creates:
```
parent
├── child1
└── child2
```

#### Built-in Object Properties

| Property | Type | Description |
|----------|------|-------------|
| `parent` | Object | The parent object in the hierarchy |
| `children` | Array | Array of child objects |
| `z` | Number | Z-index for drawing order (higher = front) |
| `enabledSelf` | Boolean | Whether this object is enabled |
| `isEnabled` | Boolean | Whether this object and all parents are enabled |
| `activeChild` | Object | The currently active child object |
| `isActive` | Boolean | Whether this object is active in the hierarchy |
| `isHovered` | Boolean | Whether the mouse is hovering over this object |
| `hoveredChild` | Object | The child object being hovered |
| `isPressed` | Boolean | Whether this object is currently pressed |
| `presses` | Array | Array of active press IDs |
| `press` | Number | The most recent press ID |
| `indexes` | Array | Array of mixin tables/functions |

#### Object Methods

| Method | Description |
|--------|-------------|
| `addChild(child)` | Add a child object (returns the child) |
| `removeChild(child)` | Remove a child object (returns the child) |
| `setParent(parent)` | Set parent object (returns self) |
| `isChildOf(object)` | Check if this object is a child of the given object |
| `updateChildStatus(object)` | Update child registration (internal) |
| `rebuildChildren()` | Rebuild children array (internal) |
| `refreshChildren()` | Sort children by z-index if needed (internal) |
| `send(message, ...)` | Send a message to all children that have the function |
| `broadcast(message, ...)` | Broadcast a message to all children and their descendants |

### 🔧 Classes

Use `floof.class(name, super, blueprint)` to define reusable components with inheritance and mixins.

#### Basic Class Definition

```lua
-- Simple class
local MyClass = floof.class("MyClass")

function MyClass:init(x, y)
    self.x = x or 0
    self.y = y or 0
end

function MyClass:update(dt)
    -- Update logic here
end

-- Create instance
local instance = MyClass(10, 20)
```

#### Class Inheritance

```lua
-- Base class
local Entity = floof.class("Entity")

function Entity:init(x, y)
    self.x = x
    self.y = y
end

-- Derived class
local Player = floof.class("Player", Entity)

function Player:init(x, y, speed)
    self.super.init(self, x, y)  -- Call parent constructor
    self.speed = speed
end

-- Create instance
local player = Player(100, 200, 150)
```

#### Class with Blueprint

```lua
local Enemy = floof.class("Enemy", Entity, {
    -- Class properties
    defaultSpeed = 100,
    defaultHealth = 50,
    
    -- Class methods
    takeDamage = function(self, amount)
        self.health = self.health - amount
        if self.health <= 0 then
            self:die()
        end
    end,
    
    die = function(self)
        self:remove()
    end
})

function Enemy:init(x, y, health)
    self.super.init(self, x, y)
    self.health = health or self.defaultHealth
end
```

### 🧬 Mixins

Mixins allow you to compose shared functionality into multiple classes without deep inheritance chains.

#### Creating Mixins

```lua
-- Movement mixin
local Movable = {
    moveSpeed = 100,
    
    move = function(self, dx, dy)
        self.x = self.x + dx * self.moveSpeed
        self.y = self.y + dy * self.moveSpeed
    end,
    
    moveTowards = function(self, targetX, targetY)
        local dx = targetX - self.x
        local dy = targetY - self.y
        local distance = math.sqrt(dx * dx + dy * dy)
        if distance > 0 then
            self:move(dx / distance, dy / distance)
        end
    end
}

-- Health mixin
local Health = {
    maxHealth = 100,
    
    takeDamage = function(self, amount)
        self.health = math.max(0, self.health - amount)
        if self.health <= 0 then
            self:die()
        end
    end,
    
    heal = function(self, amount)
        self.health = math.min(self.maxHealth, self.health + amount)
    end
}
```

#### Using Mixins

```lua
-- Class with multiple mixins
local Player = floof.class("Player")

-- Add mixins to the class
Player.indexes = {Movable, Health}

function Player:init(x, y)
    self.x = x
    self.y = y
    self.health = self.maxHealth
end

-- Now Player instances have access to mixin methods
local player = floof.new({}, Player, 100, 200)
player:move(1, 0)        -- From Movable mixin
player:takeDamage(20)    -- From Health mixin
```

### 📨 Messaging System

FLOOF provides a messaging system similar to Unity's SendMessage and BroadcastMessage, allowing objects to communicate with their children.

#### Send vs Broadcast

- **`send(message, ...)`** - Sends a message to immediate children only
- **`broadcast(message, ...)`** - Sends a message to all children and recursively to their descendants

#### Usage Examples

```lua
-- Define objects with message handlers
local UIElement = floof.class("UIElement")

function UIElement:show()
    self.visible = true
    print("Showing " .. self.name)
end

function UIElement:hide()
    self.visible = false
    print("Hiding " .. self.name)
end

function UIElement:onThemeChanged(theme)
    self.theme = theme
    print(self.name .. " theme changed to " .. theme)
end

local UIPanel = floof.class("UIPanel")

function UIPanel:showPanel()
    -- Send show message to immediate children only
    self:send("show")
end

function UIPanel:changeTheme(theme)
    -- Broadcast theme change to all descendants
    self:broadcast("onThemeChanged", theme)
end

-- Create hierarchy
local mainPanel = UIPanel()
local button1 = UIElement()
local button2 = UIElement()
local subPanel = UIPanel()
local subButton = UIElement()

button1.name = "Button1"
button2.name = "Button2"
subPanel.name = "SubPanel"
subButton.name = "SubButton"

button1.parent = mainPanel
button2.parent = mainPanel
subPanel.parent = mainPanel
subButton.parent = subPanel

-- Send message to immediate children only
mainPanel:showPanel()  -- Only Button1, Button2, and SubPanel receive "show"

-- Broadcast message to all descendants
mainPanel:changeTheme("dark")  -- Button1, Button2, SubPanel, AND SubButton receive "onThemeChanged"
```

#### Message Restrictions

Messages cannot be:
- Callback names (`update`, `draw`, `pressed`, etc.)
- Object methods (`send`, `broadcast`, `isChildOf`, etc.)
- Object properties (`parent`, `children`, `z`, etc.)

This prevents conflicts with internal FLOOF functionality.

### 🎯 Hitbox Detection

FLOOF provides built-in hitbox detection functions for UI interaction and game logic.

#### Available Hitbox Types

```lua
-- Rectangle with top-left origin (LOVE2D style)
local rect = floof.new({
    x = 100, y = 100, w = 50, h = 50,
    check = floof.checks.cornerRect
})

-- Rectangle with center origin
local centerRect = floof.new({
    x = 100, y = 100, w = 50, h = 50,
    check = floof.checks.centerRect
})

-- Circle
local circle = floof.new({
    x = 100, y = 100, r = 25,
    check = floof.checks.circle
})

-- Ellipse
local ellipse = floof.new({
    x = 100, y = 100, w = 50, h = 30,
    check = floof.checks.ellipse
})

-- Polygon (convex) - uses LOVE2D format {x1, y1, x2, y2, x3, y3, ...}
local polygon = floof.new({
    vertices = {100, 100, 150, 100, 125, 150},  -- Triangle
    check = floof.checks.polygon
})

-- Union of all children
local container = floof.new({
    check = floof.checks.children
})
```

#### Custom Hitbox Functions

```lua
-- Custom hitbox function
local function customHitbox(self, x, y)
    -- Your custom logic here
    return x >= self.x and x <= self.x + self.w and
           y >= self.y and y <= self.y + self.h
end

local obj = floof.new({
    x = 100, y = 100, w = 50, h = 50,
    check = customHitbox
})
```

### 🔄 Callbacks

FLOOF automatically routes LOVE2D callbacks to your objects. Objects can implement any of these callbacks:

#### Lifecycle Callbacks

```lua
function MyObject:load()
    -- Called when the object is created
end

function MyObject:update(dt)
    -- Called every frame with delta time
end

function MyObject:draw()
    -- Called every frame for rendering
end

function MyObject:quit()
    -- Called when the application is quitting
end
```

#### Input Callbacks

```lua
function MyObject:pressed(x, y, id)
    -- Called when mouse/touch is pressed on this object
    return true  -- Return true to consume the event
end

function MyObject:released(x, y, id)
    -- Called when mouse/touch is released
end

function MyObject:moved(x, y, dx, dy, id)
    -- Called when mouse/touch is moved while pressed
end

function MyObject:hovered()
    -- Called when mouse enters this object
end

function MyObject:unhovered()
    -- Called when mouse leaves this object
end

function MyObject:scrolled(amount)
    -- Called when mouse wheel is scrolled over this object
end

function MyObject:keypressed(key, scancode, isrepeat)
    -- Called when a key is pressed
end

function MyObject:keyreleased(key, scancode)
    -- Called when a key is released
end
```

#### Hierarchy Callbacks

```lua
function MyObject:added(child)
    -- Called when a child is added
end

function MyObject:removed(child)
    -- Called when a child is removed
end

function MyObject:addedto(parent)
    -- Called when this object is added to a parent
end

function MyObject:removedfrom(parent)
    -- Called when this object is removed from a parent
end

function MyObject:activated()
    -- Called when this object becomes active
end

function MyObject:deactivated()
    -- Called when this object becomes inactive
end

function MyObject:enabled()
    -- Called when this object is enabled
end

function MyObject:disabled()
    -- Called when this object is disabled
end
```

### 📦 Array Utilities

FLOOF provides an enhanced array implementation with useful methods.

#### Creating Arrays

```lua
-- Create empty array
local arr = floof.array.new()

-- Create array with initial values
local arr = floof.array.new(1, 2, 3, 4, 5)
```

#### Array Methods

```lua
local arr = floof.array.new(1, 2, 3)

-- Add elements
arr:append(4)           -- Add to end
arr:push(5, 1)          -- Insert at specific position

-- Remove elements
local value = arr:pop()     -- Remove from end
local value = arr:pop(2)    -- Remove from specific position

-- Find elements
local index = arr:find(3)   -- Find first occurrence
arr:remove(2)               -- Remove all occurrences of value

-- Negative indexing
local last = arr[-1]        -- Last element
local secondLast = arr[-2]  -- Second to last element
```

---

## 📘 API Reference

### Core Functions

| Function | Description |
|----------|-------------|
| `floof.new(data, class, ...)` | Create a new object |
| `floof.is(value)` | Check if a value is a FLOOF object |
| `floof.class(name, super, blueprint)` | Create a new class |
| `floof.init()` | Initialize FLOOF with LOVE2D |
| `floof.setRoot(object)` | Set the root object for the hierarchy |
| `floof.getRoot()` | Get the current root object |

### Object Properties

| Property | Type | Description |
|----------|------|-------------|
| `object.parent` | Object | Parent object in hierarchy |
| `object.children` | Array | Array of child objects |
| `object.z` | Number | Z-index for drawing order |
| `object.enabledSelf` | Boolean | Local enabled state |
| `object.isEnabled` | Boolean | Global enabled state |
| `object.activeChild` | Object | Currently active child |
| `object.isActive` | Boolean | Whether object is active |
| `object.isHovered` | Boolean | Mouse hover state |
| `object.hoveredChild` | Object | Child being hovered |
| `object.isPressed` | Boolean | Press state |
| `object.presses` | Array | Active press IDs |
| `object.press` | Number | Most recent press ID |
| `object.indexes` | Array | Mixin array |

### Hitbox Checks

| Check | Required Properties | Description |
|-------|-------------------|-------------|
| `floof.checks.cornerRect` | `x, y, w, h` | Rectangle with top-left origin |
| `floof.checks.centerRect` | `x, y, w, h` | Rectangle with center origin |
| `floof.checks.circle` | `x, y, r` | Circle with center origin |
| `floof.checks.ellipse` | `x, y, w, h` | Ellipse with center origin |
| `floof.checks.polygon` | `vertices` | Convex polygon (LOVE2D format) |
| `floof.checks.children` | `children` | Union of all children |

### Array Methods

| Method | Description |
|--------|-------------|
| `array:append(value)` | Add value to end |
| `array:push(value, position)` | Insert value at position |
| `array:pop(position)` | Remove and return value at position |
| `array:find(value)` | Find first occurrence of value |
| `array:remove(value)` | Remove all occurrences of value |

---

## 📚 Examples

### Simple Button

```lua
local Button = floof.class("Button")

function Button:init(x, y, w, h, text)
    self.x = x
    self.y = y
    self.w = w
    self.h = h
    self.text = text
    self.color = {0.8, 0.8, 0.8, 1}
    self.check = floof.checks.cornerRect
end

function Button:pressed(x, y, id)
    self.color = {0.6, 0.6, 0.6, 1}
    print("Button pressed: " .. self.text)
    return true
end

function Button:released(x, y, id)
    self.color = {0.8, 0.8, 0.8, 1}
end

function Button:hovered()
    self.color = {1, 1, 0.8, 1}
end

function Button:unhovered()
    self.color = {0.8, 0.8, 0.8, 1}
end

function Button:draw()
    love.graphics.setColor(unpack(self.color))
    love.graphics.rectangle("fill", self.x, self.y, self.w, self.h)
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.print(self.text, self.x + 5, self.y + 5)
end
```

### Draggable Object

```lua
local Draggable = floof.class("Draggable")

function Draggable:init(x, y, w, h)
    self.x = x
    self.y = y
    self.w = w
    self.h = h
    self.check = floof.checks.cornerRect
    self.isDragging = false
    self.dragOffset = {x = 0, y = 0}
end

function Draggable:pressed(x, y, id)
    self.isDragging = true
    self.dragOffset.x = x - self.x
    self.dragOffset.y = y - self.y
    return true
end

function Draggable:released(x, y, id)
    self.isDragging = false
end

function Draggable:moved(x, y, dx, dy, id)
    if self.isDragging then
        self.x = x - self.dragOffset.x
        self.y = y - self.dragOffset.y
    end
end

function Draggable:draw()
    love.graphics.setColor(1, 0, 0, 1)
    love.graphics.rectangle("fill", self.x, self.y, self.w, self.h)
end
```

### Particle System

```lua
local Particle = floof.class("Particle")

function Particle:init(x, y, vx, vy, life)
    self.x = x
    self.y = y
    self.vx = vx
    self.vy = vy
    self.life = life
    self.maxLife = life
    self.check = floof.checks.circle
    self.r = 2  -- Small radius for particle
end

function Particle:update(dt)
    self.x = self.x + self.vx * dt
    self.y = self.y + self.vy * dt
    self.life = self.life - dt
    
    if self.life <= 0 then
        self:remove()
    end
end

function Particle:draw()
    local alpha = self.life / self.maxLife
    love.graphics.setColor(1, 1, 1, alpha)
    love.graphics.circle("fill", self.x, self.y, 2)
end

-- Particle emitter
local Emitter = floof.class("Emitter")

function Emitter:init(x, y)
    self.x = x
    self.y = y
    self.emissionRate = 10  -- particles per second
    self.timer = 0
end

function Emitter:update(dt)
    self.timer = self.timer + dt
    
    while self.timer >= 1 / self.emissionRate do
        local vx = (math.random() - 0.5) * 100
        local vy = (math.random() - 0.5) * 100
        local life = math.random() * 2 + 1
        
        local particle = Particle(self.x, self.y, vx, vy, life)
        particle.parent = self.parent
        
        self.timer = self.timer - 1 / self.emissionRate
    end
end
```

### Game State Management

```lua
local GameState = floof.class("GameState")

function GameState:init()
    self.score = 0
    self.lives = 3
    self.level = 1
    self.isGameOver = false
end

function GameState:addScore(points)
    self.score = self.score + points
    if self.score >= self.level * 1000 then
        self:nextLevel()
    end
end

function GameState:loseLife()
    self.lives = self.lives - 1
    if self.lives <= 0 then
        self:gameOver()
    end
end

function GameState:nextLevel()
    self.level = self.level + 1
    print("Level " .. self.level .. "!")
end

function GameState:gameOver()
    self.isGameOver = true
    print("Game Over! Final Score: " .. self.score)
end

function GameState:reset()
    self.score = 0
    self.lives = 3
    self.level = 1
    self.isGameOver = false
end
```

---

## 🔧 Advanced Usage

### Custom Metamethods

```lua
local CustomObject = floof.class("CustomObject")

function CustomObject:init(value)
    self.value = value
end

-- Custom tostring
function CustomObject:tostring()
    return "CustomObject(" .. self.value .. ")"
end

-- Custom indexing
function CustomObject:__index(key)
    if key == "doubled" then
        return self.value * 2
    end
end
```

### Object Pooling

```lua
local ObjectPool = floof.class("ObjectPool")

function ObjectPool:init(objectClass, initialSize)
    self.objectClass = objectClass
    self.pool = {}
    
    -- Pre-populate pool
    for i = 1, initialSize do
        table.insert(self.pool, objectClass())
    end
end

function ObjectPool:get()
    if #self.pool > 0 then
        return table.remove(self.pool)
    else
        return self.objectClass()
    end
end

function ObjectPool:returnToPool(object)
    object.parent = nil
    table.insert(self.pool, object)
end
```

### Event System

```lua
local EventEmitter = floof.class("EventEmitter")

function EventEmitter:init()
    self.listeners = {}
end

function EventEmitter:on(event, callback)
    if not self.listeners[event] then
        self.listeners[event] = {}
    end
    table.insert(self.listeners[event], callback)
end

function EventEmitter:emit(event, ...)
    if self.listeners[event] then
        for _, callback in ipairs(self.listeners[event]) do
            callback(...)
        end
    end
end
```

---

## 🎮 InputSystem

FLOOF includes a comprehensive event-based input system designed for games, with support for multiple input types, processors, and configuration management. All input is handled through LOVE2D callbacks, providing efficient event-driven input processing.

### Quick Start

```lua
-- Initialize FLOOF (automatically initializes InputSystem)
floof.init()

-- Create a control scheme
local scheme = floof.inputSystem.createControlScheme("Player1", {
    {
        name = "Move",
        type = "vector",
        bindings = {
            {
                type = "axis_composite",
                x_axis = {joystick = joystick, value = 1},
                y_axis = {joystick = joystick, value = 2}
            }
        }
    },
    {
        name = "Jump",
        type = "button",
        bindings = {
            {type = "key", value = "space"},
            {type = "joystick", joystick = joystick, value = 1}
        }
    }
})

-- Create an input user
local player1 = floof.inputSystem.createInputUser(scheme)

-- Get input values (updated automatically via events)
local moveInput = player1:getValue("Move")
local isJumping = player1:isPressed("Jump")

-- Event callbacks
player1:onControlChanged("Jump", function(context)
    if context.pressed then
        print("Jump pressed!")
    end
end)
```

### Control Schemes

Control schemes define the mapping between input devices and game actions:

```lua
-- Create a control scheme
local gameScheme = inputSystem.createControlScheme("game", {
    movement = {
        name = "movement",
        type = "vector",
        bindings = {
            {type = "key_negative", value = "a"},
            {type = "key_positive", value = "d"},
            {type = "key_negative", value = "w"},
            {type = "key_positive", value = "s"}
        }
    },
    jump = {
        name = "jump",
        type = "button",
        bindings = {
            {type = "key", value = "space"}
        }
    },
    attack = {
        name = "attack",
        type = "button",
        bindings = {
            {type = "key", value = "j"},
            {type = "mouse", value = 1}
        }
    }
})

-- Create an input user with this scheme
local player1 = inputSystem.createInputUser(gameScheme)
```

### Input Types

#### Button
Boolean input (true/false) with press/release detection:

```lua
{
    name = "jump",
    type = "button",
    bindings = {
        {type = "key", value = "space"},
        {type = "joystick", value = 1, joystickId = 1}
    }
}
```

#### Axis
Continuous input ranging from -1 to 1:

```lua
{
    name = "trigger",
    type = "axis",
    bindings = {
        {type = "joystick", value = 5, joystickId = 1},
        {type = "key_positive", value = "e"}
    }
}
```

#### Vector
2D input with x/y components:

```lua
{
    name = "movement",
    type = "vector",
    bindings = {
        {type = "axis_composite", x_axis = 1, y_axis = 2, x_joystickId = 1, y_joystickId = 1},
        {type = "mouse_delta"}
    }
}
```

### Processors

Processors modify input values before they're used:

```lua
-- Deadzone - removes small input values
inputSystem.addProcessor(1, "movement", "deadzone", 0.1)

-- Scale - multiplies input by a factor
inputSystem.addProcessor(1, "movement", "scale", 2.0)

-- Clamp - limits input to a range
inputSystem.addProcessor(1, "movement", "clamp", -0.5, 0.5)

-- Normalize - scales vector to unit length
inputSystem.addProcessor(1, "look", "normalize")

-- Smooth - applies smoothing
inputSystem.addProcessor(1, "movement", "smooth", 0.8)

-- Invert - inverts input values
inputSystem.addProcessor(1, "camera", "invert")

-- Curve - applies mathematical curves
inputSystem.addProcessor(1, "movement", "curve", "exponential", 2)
```

### Device Pairing

Input users can be paired with specific devices:

```lua
-- Create user paired with keyboard/mouse
local keyboardUser = inputSystem.createInputUser(gameScheme, {"keyboard_1", "mouse_1"})

-- Create user paired with specific joystick
local joystickUser = inputSystem.createInputUser(gameScheme, {"joystick_1"})

-- Create user that listens to all devices
local allDevicesUser = inputSystem.createInputUser(gameScheme, {})
```

### Configuration

Save and load input configurations:

```lua
-- Save current configuration
inputSystem.saveConfig("my_game_input.yaml")

-- Load configuration
inputSystem.loadConfig("my_game_input.yaml")
```

### Rebinding

Rebinding happens at the InputUser level, allowing each user to have different bindings for the same controls:

```lua
-- Rebind a single control
player1:rebindControl("jump", {
    {type = "key", value = "space"},
    {type = "joystick", joystick = joystick, value = 1}
})

-- Save individual control rebind
player1:saveControlRebind("jump", "jump_rebind.yaml")

-- Load individual control rebind
player1:loadControlRebind("jump", "jump_rebind.yaml")

-- Save all user rebinds
player1:saveAllRebinds("player1_rebinds.yaml")

-- Load all user rebinds
player1:loadAllRebinds("player1_rebinds.yaml")
```

### FLOOF Integration

The InputSystem is automatically available through `floof.inputSystem` and is fully integrated with FLOOF's event system:

```lua
local Player = floof.Class("Player")

function Player:init()
    -- Create input user for this player
    self.inputUser = floof.inputSystem.createInputUser(gameScheme)
    
    -- Add processors
    self.inputUser:addProcessor("movement", "deadzone", 0.1)
    self.inputUser:addProcessor("movement", "scale", 2.0)
    
    -- Register event callbacks (automatically called when input changes)
    self.inputUser:onControlChanged("jump", Player.onJump, self)
    self.inputUser:onControlChanged("movement", Player.onMovement, self)
    
    -- Load user's custom rebinds if they exist
    self.inputUser:loadAllRebinds("player1_rebinds.yaml")
end

function Player:update(dt)
    -- Input values are automatically updated via events
    local moveX = self.inputUser:getValue("movement")
    local jump = self.inputUser:isPressed("jump")
    
    -- Apply movement
    self.x = self.x + moveX.x * self.speed * dt
    self.y = self.y + moveX.y * self.speed * dt
    
    if jump then
        self:jump()
    end
end

function Player:onJump(context)
    if context.pressed then
        self:jump()
    end
end

-- Save rebinds when player quits
function Player:quit()
    self.inputUser:saveAllRebinds("player1_rebinds.yaml")
end
```

### Multiplayer Setup

```lua
-- Create multiple players with different devices
local player1 = inputSystem.createInputUser(gameScheme, {"keyboard_1", "mouse_1"})
local player2 = inputSystem.createInputUser(gameScheme, {"joystick_1"})
local player3 = inputSystem.createInputUser(gameScheme, {"joystick_2"})

-- In update loop
function love.update(dt)
    -- Player 1 input
    local p1Move = inputSystem.getValue(1, "movement")
    local p1Jump = inputSystem.isPressed(1, "jump")
    
    -- Player 2 input
    local p2Move = inputSystem.getValue(2, "movement")
    local p2Jump = inputSystem.isPressed(2, "jump")
    
    -- Update game objects
    player1:move(p1Move)
    player2:move(p2Move)
end
```

### Event Registry

Input users can register callbacks for control state changes:

```lua
-- Register callback for object method
player1:onControlChanged("jump", Player.onJump, player1)

-- Register solo function callback
player1:onControlChanged("movement", function(context)
    print("Movement changed:", context.value.x, context.value.y)
end)

-- Remove callback
player1:offControlChanged("jump", Player.onJump, player1)
```

The callback context provides:
- `control`: Reference to the control object
- `controlName`: Name of the control
- `value`: Current input value
- `pressed`: Whether the control was pressed this frame
- `released`: Whether the control was released this frame
- `down`: Whether the control is currently down
- `delta`: For vector controls, the change since last frame
- `lastValue`: Previous input value

### Binding Validation

The system automatically validates bindings and handles device connections:

```lua
-- Invalid binding will be rejected
local success = inputSystem.rebindControl(1, "jump", {
    {type = "joystick", value = 1, joystickId = 999} -- Invalid joystick ID
})

if not success then
    print("Failed to rebind control")
end
```

### Configuration File Format

The system uses YAML-like configuration files:

```yaml
controlSchemes:
  default:
    controls:
      movement:
        name: "movement"
        type: "vector"
        bindings:
          - type: "key_negative"
            value: "a"
          - type: "key_positive"
            value: "d"
      jump:
        name: "jump"
        type: "button"
        bindings:
          - type: "key"
            value: "space"
inputUsers:
  player1:
    controlScheme: "default"
    pairedDevices: []
    enabled: true
```

---

## 🐛 Troubleshooting

### Common Issues

**Q: Objects aren't receiving input events**

A: FLOOF includes both a simple input system for UI and an InputSystem for games. For simple UI interactions, the basic input system is automatically hooked. For advanced game input with processors and configuration, use the InputSystem.

**Q: Objects aren't drawing**
A: Check that your objects have a `draw` method and are enabled (`enabledSelf = true`)

**Q: Hierarchy isn't working**
A: Ensure you're setting `parent` property correctly and objects are in the same hierarchy

**Q: Hitbox detection isn't working**
A: Verify your object has the correct `check` function and required properties (x, y, w, h, etc.)

**Q: Classes aren't inheriting properly**
A: Make sure you're calling `self.super.init(self, ...)` in derived class constructors

### Debug Tips

```lua
-- Enable debug mode
floof.debug = true

-- Print object hierarchy
function printHierarchy(obj, indent)
    indent = indent or ""
    print(indent .. obj.name)
    for _, child in ipairs(obj.children) do
        printHierarchy(child, indent .. "  ")
    end
end

-- Check if object is valid
if floof.is(myObject) then
    print("Valid FLOOF object")
else
    print("Not a FLOOF object")
end
```

---

## 📄 License

MIT License. See [LICENSE](LICENSE) for details.

---

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request. For major changes, please open an issue first to discuss what you would like to change.

### Development Setup

1. Clone the repository
2. Create a test project
3. Run the test suite: `love tests`
4. Try the demos: `love demos`

### Code Style

- Use descriptive variable names
- Add comments for complex logic
- Follow the existing code structure
- Test your changes thoroughly
