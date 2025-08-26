# FLOOF

***F**ast **L**ua **O**bject-**O**riented **F**ramework*

A lightweight and intuitive object system for LOVE2D, featuring a powerful class system, automatic callback routing, and flexible hierarchy management.

FLOOF helps you build your game using clean, modular Lua code. With built-in support for hierarchy, automatic callback routing, and flexible class-based logic, it makes structuring your game world feel natural and smooth.

---

## ✨ Features

👨‍👧‍👦 **Object Hierarchy** — nest objects with parent-child relationships and automatic transform inheritance

🧠 **Class System** — define reusable behaviors and extendable object types using pure Lua with inheritance and metamethods

🧩 **Automatic Callback Routing** — LOVE2D callbacks (update, draw, input, etc.) are automatically routed to objects

🔄 **Mouse & Input Handling** — built-in mouse detection, hover states, and input event management

🧼 **Clean & Independent** — pure Lua, zero external dependencies

---

## 📦 Installation

```bash
git clone https://github.com/mk8-bruh/floof.git
```

Place the `floof/` directory in your project, and require the core modules as needed:

```lua
local Object = require("object")
local class = require("class")
local Array = require("array")
local Vector = require("vector")
```

FLOOF has no dependencies beyond LOVE2D and Lua 5.1+

---

## 🚀 Quick Start

```lua
-- main.lua
local Object = require("object")

-- Create a custom class
local Player = Object:derive("Player")

function Player:init(data)
    self.x = data.x or 0
    self.y = data.y or 0
    self.w = data.w or 32
    self.h = data.h or 32
    self.speed = data.speed or 100
end

function Player:update(dt)
    if love.keyboard.isDown("left") then
        self.x = self.x - self.speed * dt
    end
    if love.keyboard.isDown("right") then
        self.x = self.x + self.speed * dt
    end
end

function Player:draw()
    love.graphics.rectangle("fill", self.x, self.y, self.w, self.h)
end

function Player:check(x, y)
    return x >= self.x and x <= self.x + self.w and 
           y >= self.y and y <= self.y + self.h
end

function love.load()
    -- Create root object and set it as global root
    local root = Object()
    Object.setRoot(root)
    
    -- Create player and add to hierarchy
    local player = Player{x = 100, y = 100}
    player:setParent(root)
    
    -- Register LOVE callbacks
    Object.registerCallbacks()
end
```

---

## 🧱 Core Concepts

### 🧸 Objects

The basic building block of the FLOOF hierarchy is an `Object`. Objects can be nested to create hierarchies:

```lua
local parent = Object()
local child1 = Object()
local child2 = Object()

child1:setParent(parent)
child2:setParent(parent)

-- Hierarchy: parent -> child1, child2
```

Objects automatically inherit from `Object.root` if no parent is specified.

### 🔧 Classes

Use `Object:derive(name)` to create subclasses:

```lua
local MyClass = Object:derive("MyClass")

function MyClass:init(data)
    -- Initialize with data
    self.x = data.x or 0
    self.y = data.y or 0
end

function MyClass:update(dt)
    -- Custom update logic
end

function MyClass:draw()
    -- Custom drawing logic
end
```

### 🔄 Callbacks

FLOOF supports automatic LOVE2D-style callbacks:

- **Lifecycle**: `load`, `update`, `draw`, `quit`
- **Input**: `pressed`, `released`, `moved`, `hovered`, `unhovered`
- **Keyboard**: `keypressed`, `keyreleased`, `textinput`
- **Mouse**: `scrolled`, `mousedelta`
- **System**: `resize`, `filedropped`, `joystickadded`, etc.

Your objects can implement these and they'll be routed automatically:

```lua
function MyObject:pressed(x, y, id)
    print("Clicked at", x, y)
    return true -- Consume the event
end

function MyObject:hovered()
    self.color = {1, 0, 0} -- Turn red when hovered
end
```

### 🎯 Mouse Detection

Objects can define their own hit detection:

```lua
function MyObject:check(x, y)
    -- Rectangle hit detection
    return x >= self.x and x <= self.x + self.w and 
           y >= self.y and y <= self.y + self.h
end
```

Or use built-in check functions:

```lua
-- Set check to true for always-hit objects
self.check = true

-- Use built-in rectangle check
self.check = Object.checks.cornerRect
```

### 🎨 Enabled State

Objects can be enabled/disabled to control their participation in the system:

```lua
object.enabledSelf = false  -- Disable this object
object.enabledSelf = true   -- Enable this object
```

Disabled objects won't receive callbacks or be drawn.

### 📐 Z-Ordering

Objects are sorted by their `_z` value (higher values are drawn first):

```lua
object._z = 1  -- Higher z = drawn first
```

---

## 📚 Additional Modules

### Array

A flexible array class with arithmetic operations:

```lua
local Array = require("array")

local arr1 = Array{1, 2, 3}
local arr2 = Array{4, 5, 6}

local sum = arr1 + arr2  -- Element-wise addition
local scaled = arr1 * 2  -- Scalar multiplication
```

### Vector

A 2D vector class with mathematical operations:

```lua
local Vector = require("vector")

local v1 = Vector(3, 4)
local v2 = Vector(1, 2)

local sum = v1 + v2
local length = v1:length()
local normalized = v1:normalized()
```

---

## 📘 API Reference

### Object Methods

- `Object:derive(name)` - Create a subclass
- `object:setParent(parent)` - Set parent object
- `object:check(x, y)` - Hit detection
- `Object.setRoot(root)` - Set global root object
- `Object.registerCallbacks()` - Register LOVE callbacks

### Properties

- `object.enabledSelf` - Enable/disable object
- `object.isEnabled` - Check if object and parents are enabled
- `object.isHovered` - Check if mouse is over object
- `object.isPressed` - Check if object is being pressed
- `object._z` - Z-order for drawing

### Built-in Check Functions

- `Object.checks.cornerRect` - Rectangle with top-left origin
- `Object.checks.centerRect` - Rectangle with center origin
- `Object.checks.circle` - Circle with center origin
- `Object.checks.children` - Union of all child checks

---

## 📄 License

MIT License. See LICENSE for details.
