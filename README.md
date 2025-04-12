# FLOOF

***F**ast **L**ua **O**bject-**O**riented **F**ramework*

A lightweight and intuitive object system for LOVE2D, inspired by Unity’s MonoBehaviour model.

FLOOF helps you build your game using clean, modular Lua code. With built-in support for hierarchy, automatic callback routing, and flexible class-based logic, it makes structuring your game world feel natural and smooth.

---

## ✨ Features

👨‍👧‍👦 OBJECT hierarchy — nest objects with parent-child relationships and automatic transform inheritance

🧠 CLASS system — define reusable behaviors and extendable object types using pure Lua

🧩 Mixins support through INDEXES — compose shared functionality into multiple classes

🔄 LOVE2D Integration — automatically route LOVE's update, draw, input, and other lifecycle callbacks to objects

🧼 Clean & independent — pure Lua, zero external dependencies

---

## 📦 Installation

```bash
git clone https://github.com/yourusername/floof.git
```

Place the `floof/` directory in your project, and require the core modules as needed:

```lua
floof = require("floof")
```

FLOOF has no dependencies beyond LOVE2D and Lua 5.1+

---

## 🚀 Quick Start

```lua
-- main.lua
floof = require("floof")

World = floof.class("World")

Entity = floof.class("Entity")

function Entity:init(world, x, y, w, h)
    self.x, self.y, self.w, self.h = x, y, w, h
end

Player = floof.class("Player", Entity)

function Player:init()
    self.x, self.y = 100, 100
end

function Player:update(dt)
    self.x = self.x + 50 * dt
end

function Player:draw()
    love.graphics.rectangle("fill", self.x, self.y, 32, 32)
end

-- Create a root GameObject and attach the Player behavior
function love.load()
    player = Player()
end

-- Hook into LOVE2D callbacks
function love.update(dt) floof.update(dt) end
function love.draw() floof.draw() end

```

---

## 🧱 Core Concepts

### 🧸 Objects

The basic building block of the FLOOF hierarchy is an `object`

You can nest them to create hierarchies:

```lua
local parent = floof.new{
    children = {
        floof.new{ name = "child1" }
    }
}
local child2 = floof.new{ parent = parent }
```

Built-in fields:

*WIP*

---

### 🔧 Classes
Use `floof.class(name, super, blueprint)` to define reusable components:

```lua
MyBehavior = floof.class("MyBehavior", BaseBehavior, {
    classValue = ...
})
```

Supports class or instance methods and variables, single-class inheritance, and mixins through `indexes`

---

### 🧬 Mixins

Create mixin tables and include them in a class:

```lua
-- WIP
```

---

### 🔄 Callbacks

FLOOF supports automatic LOVE2D-style callbacks:

`load`, `update`, `draw`, `keypressed`, `mousemoved`, `mousepressed`, etc.

Your objects can implement these and they'll be routed automatically:

```lua
function FallingObject:update(dt)
    self.velocity = self.velocity + gravity * dt
end
```

---

### 📘 API Reference (WIP)

---

### 📚 Examples (WIP)

---

### 📄 License

MIT License. See LICENSE.md for details.
