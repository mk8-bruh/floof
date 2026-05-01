# floof

**FLOOF** — *Fast Lua Object-Oriented Framework.*

A Lua framework providing a class system with single inheritance, properties (getters/setters), per-class/per-instance metamethods, and a set of built-in classes for vector math, dynamic arrays and (with [LÖVE](https://love2d.org)) a complete scene-graph / UI layout system.

## Installation/Usage

[Clone this repo](https://github.com/git-guides/git-clone) or download the files into a `/floof/` folder inside your project, then require it in your scripts.

To clone `FLOOF` as a submodule, first [initialize Git](https://github.com/git-guides/git-init) in your project, then run
```
git submodule add https://github.com/mk8-bruh/floof [[PATH]]
```
from your project's root directory. Doing this allows you to easily update the library by running
```
git submodule update
```

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

## Documentation

The full reference docs live in the [GithHub wiki](https://github.com/mk8-bruh/floof/wiki).

## Learning resources

floof assumes some familiarity with Lua, LÖVE, and basic object-oriented programming. If any of those are new to you, here are good places to start:

### Lua

- [Programming in Lua](https://www.lua.org/pil/contents.html)
- [Lua 5.1 Reference Manual](https://www.lua.org/manual/5.1/)
- [learnxinyminutes.com — Lua](https://learnxinyminutes.com/lua/) 

### LÖVE

- [Official LÖVE wiki](https://love2d.org/wiki/Main_Page)
- [Sheepolution's *How to LÖVE*](https://sheepolution.com/learn/book/contents) *(this is where I started with Lua and LÖVE)*
- [awesome-love2d](https://github.com/love2d-community/awesome-love2d)

### Object-oriented programming

- [Wikipedia — Object-oriented programming](https://en.wikipedia.org/wiki/Object-oriented_programming)
- [educative.io blog — OOP explained](https://www.educative.io/blog/object-oriented-programming)
- [Programming in Lua, Chapter 16](https://www.lua.org/pil/16.html) *(this is what floof actually does under the hood)*

> These are my personal picks, there are many other great resources out there if you search up the keywords :D