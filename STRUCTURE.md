# FLOOF Library Structure

## Overview

The FLOOF library has been structured to improve maintainability and organization. The object logic is split into focused modules, tied together with clean require-based dependencies.

## Structure

```
floof/
├── init.lua              # Main library entry point
├── core/                 # Core modules
│   ├── init.lua         # Core module exports
│   ├── object.lua       # Object creation and management
│   ├── class.lua        # Class system
│   ├── input.lua        # Input handling (mouse, touch, keyboard)
│   ├── hitbox.lua       # Hitbox detection functions for UI interaction
│   └── array.lua        # Array utilities
├── README.md
└── STRUCTURE.md
```

## Module Responsibilities

### `core/object.lua`
- Object creation and lifecycle management
- Parent-child hierarchy management
- Property getters/setters (parent, children, z, enabled, etc.)
- Default callback routing to children
- Object identification and validation

### `core/class.lua`
- Class definition and inheritance
- Mixin support through indexes
- Class instantiation (delegated to object module)
- Named class registry

### `core/input.lua`
- Mouse, touch, and keyboard input handling
- Input state management (presses, hover, etc.)
- LOVE2D input callback hooking
- Input property getters (isHovered, presses, etc.)

### `core/hitbox.lua`
- Pre-defined hitbox detection functions for UI interaction
- Common shape hitbox checks (rectangle, circle, etc.)
- Hitbox check creation utilities

### `core/array.lua`
- Enhanced array implementation
- Array methods (push, pop, append, find, remove)
- Negative indexing support