# floof

**FLOOF** — *Fast Lua Object-Oriented Framework.*

A Lua framework providing a class system with single inheritance, properties (getters/setters), per-class/per-instance metamethods, and a set of built-in classes for vector math, dynamic arrays and (with [LÖVE](https://love2d.org)) a complete scene-graph / UI layout system.

## Installation/Usage

[Clone this repo](https://github.com/git-guides/git-clone) or download the files into a `/floof/` folder inside your project, then require it in your scripts.

To clone `FLOOF` as a submodule, first [initialize Git](https://github.com/git-guides/git-init) in your project, then run `git submodule add https://github.com/mk8-bruh/floof [[PATH]]` from your project's root directory. Doing this allows you to easily update the library by running `git submodule update`.

If you've never used Git before, you can check out these pages:
- [install Git](https://github.com/git-guides/install-git)
- [start a repository](https://docs.github.com/en/get-started/start-your-journey/hello-world)
- or search up any other Git tutorial, there are dozens out there :)

## Quick example (LÖVE)

```lua
floof   = require("floof")
Object  = floof.object
Element = floof.element

Box = Element:class("Box")
function Box:draw()
    if self.isPressed then
        love.graphics.setColor(1, 0.85, 0)
    elseif self.isHovered then
        love.graphics.setColor(1, 1, 0.65)
    else
        love.graphics.setColor(1, 1, 1)
    end
    love.graphics.rectangle("line", self.l, self.t, self.w, self.h)
end

Box{ width = "10%", height = "10%" }
Box{ width = "10%", height = "10%" }

Object.initialize(arg)
```