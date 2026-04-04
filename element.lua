-- FLOOF: Fast Lua Element-Oriented Framework
-- Copyright (c) 2026 Matus Kordos

local PATH = (...):match("^(.+%.).-$") or ""
local floof = require(PATH)
local array, vec, Object = floof.array, floof.vector, floof.object

local Element = Object:class("Element")

-- function pre-defs

local dx, dy,
      dw, dh,
      dmx, dmy,
      dpx, dpy,
      ds,
      addToLayout, removeFromLayout

local isBefore,
      setSortOrder,
      moveBefore, moveAfter,
      setFirstChild, setLastChild,
      elementAncestors,
      iterateElement, backtrackElement,
      iterateElementChildren, backtrackElementChildren,
      previousActiveElement, nextActiveElement,
      firstActiveChildElement, lastActiveChildElement,
      previousElementInHierarchy, nextElementInHierarchy,
      iterateElementHierarchy, backtrackElementHierarchy

-- private environment

local Element_p = {
    w = 0, h = 0,
    lp = 0, tp = 0, rp = 0, bp = 0,
    leftPadding = nil, topPadding = nil, rightPadding = nil, bottomPadding = nil,
    layoutDirection = "column", justifyChildren = "top", alignChildren = "center",
    space = 0, spacing = nil, spaceAround = false, expandSpace = false, extraSpace = 0,
    firstChildElement = nil, lastChildElement = nil, layoutCount = 0,
    layoutContentSize = 0, scroll = 0, minScroll = 0, maxScroll = 0
}
local priv = setmetatable({[Element] = Element_p}, {__mode = "k"})
local initialized    = setmetatable({}, {__mode = "k"})
local firstActivated = setmetatable({}, {__mode = "k"})
local active         = setmetatable({}, {__mode = "k"})
local deleted        = setmetatable({}, {__mode = "k"})
local before         = setmetatable({}, {__mode = "k"})

local function initPrivInstance(self)
    local p = {
        parentElement = nil,
        previousElement = nil, nextElement = nil, sortingPriority = 0,
        x  = 0, y  = 0, w  = 0, h  = 0,
        l  = 0, t  = 0, r  = 0, b  = 0,
        lm = 0, tm = 0, rm = 0, bm = 0,
        lp = 0, tp = 0, rp = 0, bp = 0,
        width = nil, height = nil, aspectRatio = nil,
        alignX = "center", alignY = "center", anchorX = "center", anchorY = "center",
        leftMargin  = nil, topMargin  = nil, rightMargin  = nil, bottomMargin  = nil,
        leftPadding = nil, topPadding = nil, rightPadding = nil, bottomPadding = nil,
        inLayout = true, layoutIndex = nil, ox = 0, oy = 0,
        layoutDirection = "column", justifyChildren = "top", alignChildren = "center",
        space = 0, spacing = nil, spaceAround = false, expandSpace = false, extraSpace = 0,
        firstChildElement = nil, lastChildElement = nil, layoutCount = 0,
        layoutContentSize = 0, scroll = 0, minScroll = 0, maxScroll = 0
    }
    priv[self] = p
    return p
end

-- helpers

local function validateElement(self, name, acceptClass)
    local typeStr = acceptClass and "Element instance or the class" or "Element instance"
    if not (acceptClass and self == Element) and
       not floof.instanceOf(self, Element)
    then
        error(("Invalid %s: %s expected, got %s"):format(name, typeStr, floof.typeOf(self)), 3)
    elseif not priv[self] then
        error(("Invalid %s: Element not properly constructed"):format(name), 3)
    elseif deleted[self] then
        error(("Invalid %s: deleted"):format(name), 3)
    end
end

local function handleCallback(self, func, ...)
    if not initialized[self] then return false
    elseif floof.isCallable(self[func]) then
        local s, e = pcall(self[func], self, ...)
        if not s then error(e, 3) else return e end
    else return self[func] end
end

local function privKeyIterator(k) return floof.newIterator(function(self) return priv[self] and priv[self][k] end) end

-- public interface

function Element:isConstructed() return priv[self] ~= nil end

local getters = {
    parentElement = priv,
    previousElement = priv, nextElement = priv, sortingPriority = priv,
    x  = priv, y  = priv, w  = priv, h  = priv,
    l  = priv, t  = priv, r  = priv, b  = priv,
    lm = priv, tm = priv, rm = priv, bm = priv,
    lp = priv, tp = priv, rp = priv, bp = priv,
    width = priv, height = priv, aspectRatio = priv,
    alignX = priv, alignY = priv, --anchorX = priv, anchorY = priv,
    leftMargin  = priv, topMargin  = priv, rightMargin  = priv, bottomMargin  = priv,
    leftPadding = priv, topPadding = priv, rightPadding = priv, bottomPadding = priv,
    inLayout = priv, layoutIndex = priv, ox = priv, oy = priv,
    layoutDirection = priv, justifyChildren = priv, alignChildren = priv,
    space = priv, spacing = priv, spaceAround = priv, expandSpace = priv, --extraSpace = priv,
    firstChildElement = priv, lastChildElement = priv, layoutCount = priv,
    layoutContentSize = priv, scroll = priv, minScroll = priv, maxScroll = priv
}
function Element:__get(k)
    if priv[self] and getters[k] then
        if getters[k] == priv then
            return priv[self][k]
        else
            return floof.safeReturn(getters[k], self)
        end
    end
    return floof.safeReturn(floof.get, Object, self, k)
end

local setters = {}
function Element:__set(k, v)
    if priv[self] and (setters[k] or getters[k]) then
        if not setters[k] then
            error(("Cannot modify private field %q"):format(k), 2)
        else
            floof.safeInvoke(setters[k], self, v)
        end
    else floof.safeInvoke(floof.set, Object, self, k, v) end
end

-- positioning logic

local operations = {}
local dirty = {}

function operation(f, ...)
    local op = {func = f, ...}
    if operations.tail then
        operations[operations.tail], operations.tail = op, op
    else
        operations.head, operations.tail = op, op
    end
end

function flushOperations()
    local ops, els = 0, 0
    while operations.head do
        local op = operations.head
        local s, e = pcall(op.func, unpack(op))
        if not s then error(e, 3) end
        if operations[op] then
            operations.head, operations[op] = operations[op]
        else
            operations.head, operations.tail = nil
        end
        ops = ops + 1
    end
    for el in pairs(dirty) do
        local s, e = pcall(Object.shapeChanged, el)
        if not s then error(e, 3) end
        dirty[el] = nil
        els = els + 1
    end
    print(("\x1b[1;33m[ELEMENT]\x1b[0m flushed %d operations, modified %d elements"):format(ops, els))
end

function dx(self, d, offset)
    local self_p = priv[self]
    self_p.x = self_p.x + d
    self_p.l = self_p.l + d
    self_p.r = self_p.r + d
    if offset then self_p.ox = self_p.ox + d end
    for elem in iterateElementChildren(self) do
        operation(dx, elem, d)
    end
    dirty[self] = true
end

function dy(self, d, offset)
    local self_p = priv[self]
    self_p.y = self_p.y + d
    self_p.t = self_p.t + d
    self_p.b = self_p.b + d
    if offset then self_p.oy = self_p.oy + d end
    for elem in iterateElementChildren(self) do
        operation(dy, elem, d)
    end
    dirty[self] = true
end

local function dExtraSp(self, d)
    local self_p = priv[self]
    local ds = math.max(self_p.extraSpace - d, 0) - math.max(self_p.extraSpace, 0)
    local ns = math.max(self_p.layoutCount + (self_p.spaceAround and 1 or -1), 0)
    self_p.extraSpace = self_p.extraSpace - d
    local scr = 0
    if self_p.justifyChildren == "left" or self_p.justifyChildren == "top" then
        self_p.minScroll, self_p.maxScroll = math.min(-self_p.extraSpace, 0), 0
    elseif self_p.justifyChildren == "center" or self_p.justifyChildren == "middle" then
        self_p.minScroll, self_p.maxScroll = math.min(-self_p.extraSpace/2, 0), math.max(self_p.extraSpace/2, 0)
    elseif self_p.justifyChildren == "right" or self_p.justifyChildren == "bottom" then
        self_p.minScroll, self_p.maxScroll = 0, math.max(self_p.extraSpace, 0)
    end
    if self_p.scroll < self_p.minScroll then
        scr = self_p.minScroll - self_p.scroll
        self_p.scroll = self_p.minScroll
    elseif self_p.scroll > self_p.maxScroll then
        scr = self_p.maxScroll - self_p.scroll
        self_p.scroll = self_p.maxScroll
    end
    for elem in iterateElementChildren(self) do
        local elem_p = priv[elem]
        if elem_p.layoutIndex and ds ~= 0 and self_p.expandSpace then
            if self_p.justifyChildren == "left" then
                operation(dx, elem, -(elem_p.layoutIndex - (self_p.spaceAround and 0 or 1)) * ds / ns)
            elseif self_p.justifyChildren == "center" then
                operation(dx, elem, (elem_p.layoutIndex - (self_p.spaceAround and 0 or 1) - (self_p.layoutCount + 1) / 2) * ds / ns)
            elseif self_p.justifyChildren == "right" then
                operation(dx, elem, (self_p.layoutCount - elem_p.layoutIndex + (self_p.spaceAround and 0 or 1)) * ds / ns)
            elseif self_p.justifyChildren == "top" then
                operation(dy, elem, -(elem_p.layoutIndex - (self_p.spaceAround and 0 or 1)) * ds / ns)
            elseif self_p.justifyChildren == "middle" then
                operation(dy, elem, (elem_p.layoutIndex - (self_p.spaceAround and 0 or 1) - (self_p.layoutCount + 1) / 2) * ds / ns)
            elseif self_p.justifyChildren == "bottom" then
                operation(dy, elem, (self_p.layoutCount - elem_p.layoutIndex + (self_p.spaceAround and 0 or 1)) * ds / ns)
            end
        end
        if elem_p.inLayout and scr ~= 0 then
            if self_p.layoutDirection == "row" then
                operation(dx, elem, scr)
            elseif self_p.layoutDirection == "column" then
                operation(dy, elem, scr)
            end
        end
    end
end

function dw(self, d)
    local self_p = priv[self]
    local parent_p = priv[self_p.parentElement] or Element_p
    if self_p.anchorX == "stretch" then
        -- stretch behavior
        local l, r = self_p.leftMargin or 0, self_p.rightMargin or 0
        d = d / (1 + l + r)
        self_p.lm = self_p.lm + d * l
        self_p.rm = self_p.rm + d * r
        operation(dx, self, d * (l - r) / 2)
    else
        -- margins
        if self_p.leftMargin or self_p.rightMargin then
            operation(dmx, self,
                self_p.leftMargin  and d * self_p.leftMargin  or 0,
                self_p.rightMargin and d * self_p.rightMargin or 0
            )
        end
        -- position
        if self_p.anchorX == "left" then
            operation(dx, self, d/2)
            if parent_p.layoutDirection == "row" and self_p.layoutIndex then
                for sib in iterateElement(self) do
                    local sib_p = priv[sib]
                    if sib_p.inLayout then
                        operation(dx, sib, d)
                    end
                end
            end
        elseif self_p.anchorX == "center" then
            if parent_p.layoutDirection == "row" and self_p.layoutIndex then
                for sib in iterateElement(self) do
                    local sib_p = priv[sib]
                    if sib_p.inLayout then
                        operation(dx, sib, d/2)
                    end
                end
                for sib in backtrackElement(self) do
                    local sib_p = priv[sib]
                    if sib_p.inLayout then
                        operation(dx, sib, -d/2)
                    end
                end
            end
        elseif self_p.anchorX == "right" then
            operation(dx, self, -d/2)
            if parent_p.layoutDirection == "row" and self_p.layoutIndex then
                for sib in backtrackElement(self) do
                    local sib_p = priv[sib]
                    if sib_p.inLayout then
                        operation(dx, sib, -d)
                    end
                end
            end
        end
    end
    self_p.w = self_p.w + d
    self_p.l = self_p.l - d/2
    self_p.r = self_p.r + d/2
    -- size
    if self_p.aspectRatio then
        operation(dh, self, d / self_p.aspectRatio)
    end
    -- padding
    if self_p.leftPadding or self_p.rightPadding then
        operation(dpx, self,
            self_p.leftPadding   and d * self_p.leftPadding  or 0,
            self_p.rightPadding  and d * self_p.rightPadding or 0
        )
    end
    -- spacing
    if self_p.layoutDirection == "row" and self_p.spacing then
        operation(ds, self, d * self_p.spacing)
    end
    -- children
    for elem in iterateElementChildren(self) do
        local elem_p = priv[elem]
        -- position
        if elem_p.anchorX == "left" then
            operation(dx, elem, -d/2)
        elseif elem_p.anchorX == "right" then
            operation(dx, elem, d/2)
        end
        -- size
        if elem_p.width then
            operation(dw, elem, elem_p.width * d)
        elseif elem_p.anchorX == "stretch" then
            operation(dw, elem, d)
        end
    end
    if self_p.layoutIndex and parent_p.layoutDirection == "row" then dExtraSp(self_p.parent or Element, -d) end
    if self_p.layoutDirection == "row" then dExtraSp(self, d) end
    dirty[self] = true
end

function dh(self, d)
    local self_p = priv[self]
    local parent_p = priv[self_p.parentElement] or Element_p
    if self_p.anchorY == "expand" then
        -- stretch behavior
        local t, b = self_p.topMargin or 0, self_p.bottomMargin or 0
        d = d / (1 + t + b)
        self_p.tm = self_p.tm + d * t
        self_p.bm = self_p.bm + d * b
        operation(dy, self, d * (t - b) / 2)
    else
        -- margins
        if self_p.topMargin or self_p.bottomMargin then
            operation(dmy, self,
                self_p.topMargin    and d * self_p.topMargin    or 0,
                self_p.bottomMargin and d * self_p.bottomMargin or 0
            )
        end
        -- position
        if self_p.anchorY == "top" then
            operation(dy, self, d/2)
            if parent_p.layoutDirection == "column" and self_p.layoutIndex then
                for sib in iterateElement(self) do
                    local sib_p = priv[sib]
                    if sib_p.inLayout then
                        operation(dy, sib, d)
                    end
                end
            end
        elseif self_p.anchorY == "middle" then
            if parent_p.layoutDirection == "column" and self_p.layoutIndex then
                for sib in iterateElement(self) do
                    local sib_p = priv[sib]
                    if sib_p.inLayout then
                        operation(dy, sib, d/2)
                    end
                end
                for sib in backtrackElement(self) do
                    local sib_p = priv[sib]
                    if sib_p.inLayout then
                        operation(dy, sib, -d/2)
                    end
                end
            end
        elseif self_p.anchorY == "bottom" then
            operation(dy, self, -d/2)
            if parent_p.layoutDirection == "column" and self_p.layoutIndex then
                for sib in backtrackElement(self) do
                    local sib_p = priv[sib]
                    if sib_p.inLayout then
                        operation(dy, sib, -d)
                    end
                end
            end
        end
    end
    self_p.h = self_p.h + d
    self_p.t = self_p.t - d/2
    self_p.b = self_p.b + d/2
    -- size
    if self_p.aspectRatio then
        operation(dw, self, d * self_p.aspectRatio)
    end
    -- padding
    if self_p.topPadding or self_p.bottomPadding then
        operation(dpy, self,
            self_p.topPadding     and d * self_p.topPadding    or 0,
            self_p.bottomPadding  and d * self_p.bottomPadding or 0
        )
    end
    -- spacing
    if self_p.layoutDirection == "column" and self_p.spacing then
        operation(ds, self, d * self_p.spacing)
    end
    -- children
    for elem in iterateElementChildren(self) do
        local elem_p = priv[elem]
        -- position
        if elem_p.anchorY == "top" then
            operation(dy, elem, -d/2)
        elseif elem_p.anchorY == "bottom" then
            operation(dy, elem, d/2)
        end
        -- size
        if elem_p.height then
            operation(dh, elem, elem_p.height * d)
        elseif elem_p.anchorY == "expand" then
            operation(dh, elem, d)
        end
    end
    if self_p.layoutIndex and parent_p.layoutDirection == "column" then dExtraSp(self_p.parent or Element, -d) end
    if self_p.layoutDirection == "column" then dExtraSp(self, d) end
    dirty[self] = true
end

function dmx(self, l, r)
    local self_p = priv[self]
    local parent_p = priv[self_p.parent] or Element_p
    self_p.lm = self_p.lm + l
    self_p.rm = self_p.rm + r
    local d, c = l + r, (l - r) / 2
    if self_p.anchorX == "left" then
        if l ~= 0 then operation(dx, self, l) end
        if d ~= 0 and parent_p.layoutDirection == "row" and self_p.layoutIndex then
            for sib in iterateElement(self) do
                local sib_p = priv[sib]
                if sib_p.inLayout then
                    operation(dx, sib, d)
                end
            end
        end
    elseif self_p.anchorX == "right" then
        if r ~= 0 then operation(dx, self, -r) end
        if d ~= 0 and parent_p.layoutDirection == "row" and self_p.layoutIndex then
            for sib in iterateElement(self) do
                local sib_p = priv[sib]
                if sib_p.inLayout then
                    operation(dx, sib, -d)
                end
            end
        end
    else
        if c ~= 0 then operation(dx, self, c) end
        if d ~= 0 and parent_p.layoutDirection == "row" and self_p.layoutIndex then
            for sib in iterateElement(self) do
                local sib_p = priv[sib]
                if sib_p.inLayout then
                    operation(dx, sib, d/2)
                end
            end
            for sib in backtrackElement(self) do
                local sib_p = priv[sib]
                if sib_p.inLayout then
                    operation(dx, sib, -d/2)
                end
            end
        elseif d ~= 0 and self_p.anchorX == "stretch" then
            operation(dw, self, -d)
        end
    end
    if self_p.layoutIndex and parent_p.layoutDirection == "row" then dExtraSp(self_p.parent or Element, -d) end
end

function dmy(self, t, b)
    local self_p = priv[self]
    local parent_p = priv[self_p.parent] or Element_p
    self_p.tm = self_p.tm + t
    self_p.bm = self_p.bm + b
    local d, c = t + b, (t - b) / 2
    if self_p.anchorY == "top" then
        if t ~= 0 then operation(dy, self, t) end
        if d ~= 0 and parent_p.layoutDirection == "column" and self_p.layoutIndex then
            for sib in iterateElement(self) do
                local sib_p = priv[sib]
                if sib_p.inLayout then
                    operation(dy, sib, d)
                end
            end
        end
    elseif self_p.anchorY == "bottom" then
        if b ~= 0 then operation(dy, self, -b) end
        if d ~= 0 and parent_p.layoutDirection == "column" and self_p.layoutIndex then
            for sib in iterateElement(self) do
                local sib_p = priv[sib]
                if sib_p.inLayout then
                    operation(dy, sib, -d)
                end
            end
        end
    else
        if c ~= 0 then operation(dy, self, c) end
        if d ~= 0 and parent_p.layoutDirection == "column" and self_p.layoutIndex then
            for sib in iterateElement(self) do
                local sib_p = priv[sib]
                if sib_p.inLayout then
                    operation(dy, sib, d/2)
                end
            end
            for sib in backtrackElement(self) do
                local sib_p = priv[sib]
                if sib_p.inLayout then
                    operation(dy, sib, -d/2)
                end
            end
        elseif d ~= 0 and self_p.anchorY == "expand" then
            operation(dh, self, -d)
        end
    end
    if self_p.layoutIndex and parent_p.layoutDirection == "column" then dExtraSp(self_p.parent or Element, -d) end
end

function dpx(self, l, r)
    local self_p = priv[self]
    self_p.lp = self_p.lp + l
    self_p.rp = self_p.rp + r
    local d, c = l + r, (l - r) / 2
    -- spacing
    if self_p.layoutDirection == "row" and self_p.spacing then
        operation(ds, self, -d * self_p.spacing)
    end
    for elem in iterateElementChildren(self) do
        local elem_p = priv[elem]
        -- position
        if elem_p.anchorX == "left" and l ~= 0 then
            operation(dx, elem, l)
        elseif elem_p.anchorX == "right" and r ~= 0 then
            operation(dx, elem, -r)
        elseif c ~= 0 then
            operation(dx, elem, c)
        end
        -- size
        if d ~= 0 then
            if elem_p.width then
                operation(dw, elem, elem_p.width * -d)
            elseif elem_p.anchorX == "stretch" then
                operation(dw, elem, -d)
            end
        end
    end
    if self_p.layoutDirection == "row" then dExtraSp(self, -d) end
end

function dpy(self, t, b)
    local self_p = priv[self]
    self_p.tp = self_p.tp + t
    self_p.bp = self_p.bp + b
    local d, c = t + b, (t - b) / 2
    -- spacing
    if self_p.layoutDirection == "column" and self_p.spacing then
        operation(ds, self, -d * self_p.spacing)
    end
    for elem in iterateElementChildren(self) do
        local elem_p = priv[elem]
        -- position
        if elem_p.anchorY == "top" and t ~= 0 then
            operation(dy, elem, t)
        elseif elem_p.anchorY == "bottom" and b ~= 0 then
            operation(dy, elem, -b)
        elseif c ~= 0 then
            operation(dy, elem, c)
        end
        -- size
        if d ~= 0 then
            if elem_p.height then
                operation(dh, elem, elem_p.height * -d)
            elseif elem_p.anchorY == "stretch" then
                operation(dh, elem, -d)
            end
        end
    end
    if self_p.layoutDirection == "column" then dExtraSp(self, -d) end
end

function ds(self, d)
    local ns = math.max(self_p.layoutCount + (self_p.spaceAround and 1 or -1), 0)
    local tr
    if self_p.justifyChildren == "left" or self_p.justifyChildren == "top" then
        tr = self_p.spaceAround and -d or 0
    elseif self_p.justifyChildren == "center" or self_p.justifyChildren == "middle" then
        tr = -d * (self_p.layoutCount - 1) / 2
    elseif self_p.justifyChildren == "right" or self_p.justifyChildren == "bottom" then
        tr = -d * (self_p.layoutCount + (self_p.spaceAround and 1 or 0))
    end
    for elem in iterateElementChildren(self) do
        local elem_p = priv[elem]
        if elem_p.inLayout then
            if self_p.layoutDirection == "row" then
                operation(dx, elem, tr)
            elseif self_p.layoutDirection == "column" then
                operation(dy, elem, tr)
            end
        end
        if elem_p.layoutIndex then tr = tr + d end
    end
    dExtraSp(self, -d * ns)
end

function addToLayout(self)

end

function removeFromLayout(self)

end

-- event hooks

Element:registerHandler("constructed", function(self)
    local self_p = initPrivInstance(self)
end)

Element:registerHandler("initialized", function(self)
    local self_p = priv[self]
    initialized[self] = true
    before[self] = {}
end)

Element:registerHandler("activated", function(self)
    local self_p = priv[self]
    if firstActivated[self] then firstActivated[self] = true end
    active[self] = true
    if self_p.inLayout then
        local index = 1
        for sib in backtrackElement(self) do
            local sib_p = priv[sib]
            if sib_p.layoutIndex then
                index = sib_p.layoutIndex + 1
            end
        end
        self_p.layoutIndex = index
        for sib in iterateElement(self) do
            local sib_p = priv[sib]
            if sib_p.layoutIndex then
                sib_p.layoutIndex = sib_p.layoutIndex + 1
            end
        end
        operation(addToLayout, self)
    end
end)

Element:registerHandler("deactivated", function(self)
    local self_p = priv[self]
    active[self] = nil
    if self_p.inLayout then
        self_p.layoutIndex = nil
        for sib in iterateElement(self) do
            local sib_p = priv[sib]
            if sib_p.layoutIndex then
                sib_p.layoutIndex = sib_p.layoutIndex - 1
            end
        end
        operation(removeFromLayout, self)
    end
end)

local function added(self, parent)
    local self_p = priv[self]
    while parent and not priv[parent] do
        parent = floof.get(Object, parent, "parent")
    end
    self_p.parentElement = parent
    local parent_p = priv[parent] or Element_p
    if not parent_p.lastChildElement then
        parent_p.firstChildElement, parent_p.lastChildElement = self, self
    elseif self_p.sortingPriority <= priv[parent_p.lastChildElement].sortingPriority then
        priv[parent_p.lastChildElement].nextElement = self
        self_p.previousElement, parent_p.lastChildElement = parent_p.lastChildElement, self
    else
        for sib in backtrackElementChildren(parent or Element) do
            local sib_p = priv[sib]
            before[self][sib] = true
            if not sib_p.previousElement then
                parent_p.firstChildElement, sib_p.previousElement, self_p.nextElement = self, self, sib
            elseif priv[sib_p.previousElement].sortingPriority >= self_p.sortingPriority then
                priv[sib_p.previousElement].nextElement, self_p.previousElement = self, sib_p.previousElement
                sib_p.previousElement, self_p.nextElement = self, sib
            end
        end
    end
    for sib in backtrackElement(self) do
        before[sib][self] = true
    end
    if firstActivated[self] then return end
    if self_p.layoutIndex then
        local index = 1
        for sib in backtrackElement(self) do
            local sib_p = priv[sib]
            if sib_p.layoutIndex then
                index = sib_p.layoutIndex + 1
            end
        end
        self_p.layoutIndex = index
        for sib in iterateElement(self) do
            local sib_p = priv[sib]
            if sib_p.layoutIndex then
                sib_p.layoutIndex = sib_p.layoutIndex + 1
            end
        end
        operation(addToLayout, self)
    end
end

local function removed(self, parent)
    local self_p = priv[self]
    if self_p.layoutIndex then
        self_p.layoutIndex = nil
        for sib in iterateElement(self) do
            local sib_p = priv[sib]
            if sib_p.layoutIndex then
                sib_p.layoutIndex = sib_p.layoutIndex - 1
            end
        end
        operation(removeFromLayout, self)
    end
    for sib in backtrackElement(self) do
        before[sib][self] = nil
    end
    before[self] = {}
    local parent_p = priv[self_p.parentElement] or Element_p
    if self_p.previousElement then
        priv[self_p.previousElement].nextElement = self_p.nextElement
    else
        parent_p.firstChildElement = self_p.nextElement
    end
    if self_p.nextElement then
        priv[self_p.nextElement].previousElement = self_p.previousElement
    else
        parent_p.lastChildElement = self_p.previousElement
    end
    self_p.parentElement, self_p.nextElement, self_p.previousElement = nil
end

Element:registerHandler("addedto",     added)
Element:registerHandler("orphaned",    added)
Element:registerHandler("removedfrom", removed)
Element:registerHandler("adopted",     removed)

Element:registerHandler("deleted", function(self)
    local self_p = priv[self]
    removed(self, self_p.parentElement)
    deleted[self] = true
end)

-- properties

function setters:x(value)
    validateElement(self, "caller", false)
    if type(value) ~= "number" then
        error(("Invalid value: number expected, got %s"):(floof.typeOf(value)), 2)
    end
    local self_p = priv[self]
    operation(dx, self, value - self_p.x, self_p.inLayout)
    flushOperations()
end

function setters:y(value)
    validateElement(self, "caller", false)
    if type(value) ~= "number" then
        error(("Invalid value: number expected, got %s"):(floof.typeOf(value)), 2)
    end
    local self_p = priv[self]
    operation(dy, self, value - self_p.y, self_p.inLayout)
    flushOperations()
end

function setters:w(value)
    if type(value) ~= "number" then
        error(("Invalid value: number expected, got %s"):(floof.typeOf(value)), 2)
    end
    local self_p = priv[self]
    if self_p.width then error("Cannot modify the raw width of an Element with dynamic width", 2) end
    operation(dw, self, value - self_p.w)
    flushOperations()
end

function setters:h(value)
    if type(value) ~= "number" then
        error(("Invalid value: number expected, got %s"):(floof.typeOf(value)), 2)
    end
    local self_p = priv[self]
    if self_p.height then error("Cannot modify the raw height of an Element with dynamic height", 2) end
    operation(dh, self, value - self_p.h)
    flushOperations()
end

function setters:l(value)
    if type(value) ~= "number" then
        error(("Invalid value: number expected, got %s"):(floof.typeOf(value)), 2)
    end
    local self_p = priv[self]
    local d = value - self_p.l
    if self_p.width then
        operation(dx, self, d)
    else
        operation(dw, self, -d)
        if self_p.anchorX == "left" then
            operation(dx, self, d)
        elseif self_p.anchorX ~= "right" then
            operation(dx, self, d/2)
        end
    end
    flushOperations()
end

function setters:t(value)
    if type(value) ~= "number" then
        error(("Invalid value: number expected, got %s"):(floof.typeOf(value)), 2)
    end
    local self_p = priv[self]
    local d = value - self_p.t
    if self_p.height then
        operation(dy, self, d)
    else
        operation(dh, self, -d)
        if self_p.anchorY == "top" then
            operation(dy, self, d)
        elseif self_p.anchorY ~= "bottom" then
            operation(dy, self, d/2)
        end
    end
    flushOperations()
end

function setters:r(value)
    if type(value) ~= "number" then
        error(("Invalid value: number expected, got %s"):(floof.typeOf(value)), 2)
    end
    local self_p = priv[self]
    local d = value - self_p.r
    if self_p.width then
        operation(dx, self, d)
    else
        operation(dw, self, d)
        if self_p.anchorX == "right" then
            operation(dx, self, d)
        elseif self_p.anchorX ~= "left" then
            operation(dx, self, d/2)
        end
    end
    flushOperations()
end

function setters:b(value)
    if type(value) ~= "number" then
        error(("Invalid value: number expected, got %s"):(floof.typeOf(value)), 2)
    end
    local self_p = priv[self]
    local d = value - self_p.b
    if self_p.height then
        operation(dy, self, d)
    else
        operation(dh, self, d)
        if self_p.anchorY == "bottom" then
            operation(dy, self, d)
        elseif self_p.anchorY ~= "top" then
            operation(dy, self, d/2)
        end
    end
    flushOperations()
end

function setters:lm(value)
    if type(value) ~= "number" then
        error(("Invalid value: number expected, got %s"):(floof.typeOf(value)), 2)
    end
    local self_p = priv[self]
    if self_p.leftMargin then
        error("Cannot modify the raw margin of an Element with a dynamic margin", 2)
    end
    operation(dmx, self, value - self_p.lm, 0)
    flushOperations()
end

function setters:tm(value)
    if type(value) ~= "number" then
        error(("Invalid value: number expected, got %s"):(floof.typeOf(value)), 2)
    end
    local self_p = priv[self]
    if self_p.topMargin then
        error("Cannot modify the raw margin of an Element with a dynamic margin", 2)
    end
    operation(dmy, self, value - self_p.tm, 0)
    flushOperations()
end

function setters:rm(value)
    if type(value) ~= "number" then
        error(("Invalid value: number expected, got %s"):(floof.typeOf(value)), 2)
    end
    local self_p = priv[self]
    if self_p.rightMargin then
        error("Cannot modify the raw margin of an Element with a dynamic margin", 2)
    end
    operation(dmx, self, 0, value - self_p.rm)
    flushOperations()
end

function setters:bm(value)
    if type(value) ~= "number" then
        error(("Invalid value: number expected, got %s"):(floof.typeOf(value)), 2)
    end
    local self_p = priv[self]
    if self_p.bottomMargin then
        error("Cannot modify the raw margin of an Element with a dynamic margin", 2)
    end
    operation(dmy, self, 0, value - self_p.bm)
    flushOperations()
end

function setters:xm(value)
    if type(value) ~= "number" then
        error(("Invalid value: number expected, got %s"):(floof.typeOf(value)), 2)
    end
    local self_p = priv[self]
    if self_p.leftMargin or self_p.rightMargin then
        error("Cannot modify the raw margin of an Element with a dynamic margin", 2)
    end
    operation(dmx, self, value - self_p.lm, value - self_p.rm)
    flushOperations()
end

function setters:ym(value)
    if type(value) ~= "number" then
        error(("Invalid value: number expected, got %s"):(floof.typeOf(value)), 2)
    end
    local self_p = priv[self]
    if self_p.topMargin or self_p.bottomMargin then
        error("Cannot modify the raw margin of an Element with a dynamic margin", 2)
    end
    operation(dmy, self, value - self_p.tm, value - self_p.bm)
    flushOperations()
end

function setters:m(value)
    if type(value) ~= "number" then
        error(("Invalid value: number expected, got %s"):(floof.typeOf(value)), 2)
    end
    local self_p = priv[self]
    if self_p.leftMargin or self_p.topMargin or self_p.rightMargin or self_p.bottomMargin then
        error("Cannot modify the raw margin of an Element with a dynamic margin", 2)
    else
    operation(dmx, self, value - self_p.lm, value - self_p.rm)
    operation(dmy, self, value - self_p.tm, value - self_p.bm)
    flushOperations()
end

function setters:lp(value)
    if type(value) ~= "number" then
        error(("Invalid value: number expected, got %s"):(floof.typeOf(value)), 2)
    end
    local self_p = priv[self]
    if self_p.leftPadding then
        error("Cannot modify the raw padding of an Element with dynamic padding", 2)
    end
    operation(dpx, self, value - self_p.lp, 0)
    flushOperations()
end

function setters:tp(value)
    if type(value) ~= "number" then
        error(("Invalid value: number expected, got %s"):(floof.typeOf(value)), 2)
    end
    local self_p = priv[self]
    if self_p.topPadding then
        error("Cannot modify the raw padding of an Element with dynamic padding", 2)
    end
    operation(dpy, self, value - self_p.tp, 0)
    flushOperations()
end

function setters:rp(value)
    if type(value) ~= "number" then
        error(("Invalid value: number expected, got %s"):(floof.typeOf(value)), 2)
    end
    local self_p = priv[self]
    if self_p.rightPadding then
        error("Cannot modify the raw padding of an Element with dynamic padding", 2)
    end
    operation(dpx, self, 0, value - self_p.rp)
    flushOperations()
end

function setters:bp(value)
    if type(value) ~= "number" then
        error(("Invalid value: number expected, got %s"):(floof.typeOf(value)), 2)
    end
    local self_p = priv[self]
    if self_p.bottomPadding then
        error("Cannot modify the raw padding of an Element with dynamic padding", 2)
    end
    operation(dpy, self, 0, value - self_p.bp)
    flushOperations()
end

function setters:xp(value)
    if type(value) ~= "number" then
        error(("Invalid value: number expected, got %s"):(floof.typeOf(value)), 2)
    end
    local self_p = priv[self]
    if self_p.leftPadding or self_p.rightPadding then
        error("Cannot modify the raw padding of an Element with dynamic padding", 2)
    end
    operation(dpx, self, value - self_p.lp, value - self_p.rp)
    flushOperations()
end

function setters:yp(value)
    if type(value) ~= "number" then
        error(("Invalid value: number expected, got %s"):(floof.typeOf(value)), 2)
    end
    local self_p = priv[self]
    if self_p.topPadding or self_p.bottomPadding then
        error("Cannot modify the raw padding of an Element with dynamic padding", 2)
    end
    operation(dpy, self, value - self_p.tp, value - self_p.bp)
    flushOperations()
end

function setters:p(value)
    if type(value) ~= "number" then
        error(("Invalid value: number expected, got %s"):(floof.typeOf(value)), 2)
    end
    local self_p = priv[self]
    if self_p.leftPadding or self_p.topPadding or self_p.rightPadding or self_p.bottomPadding then
        error("Cannot modify the raw padding of an Element with dynamic padding", 2)
    else
    operation(dmx, self, value - self_p.lp, value - self_p.rp)
    operation(dmy, self, value - self_p.tp, value - self_p.bp)
    flushOperations()
end

function setters:space(value)
    if type(value) ~= "number" then
        error(("Invalid value: number expected, got %s"):(floof.typeOf(value)), 2)
    end
    local self_p = priv[self]
    if self_p.leftPadding or self_p.topPadding or self_p.rightPadding or self_p.bottomPadding then
        error("Cannot modify the raw padding of an Element with dynamic padding", 2)
    else
    operation(ds, self, value - self_p.space)
    flushOperations()
end

function setters:ox(value)
    if type(value) ~= "number" then
        error(("Invalid value: number expected, got %s"):(floof.typeOf(value)), 2)
    end
    local self_p = priv[self]
    operation(dx, self, value - self_p.ox, true)
    flushOperations()
end

function setters:oy(value)
    if type(value) ~= "number" then
        error(("Invalid value: number expected, got %s"):(floof.typeOf(value)), 2)
    end
    local self_p = priv[self]
    operation(dy, self, value - self_p.oy, true)
    flushOperations()
end

function setters:width(value)
    if value == nil then
        self_p.width = nil
        return
    elseif type(value) == "string" then
        local val = tonumber(value:match("^%s*(%d*%.?%d+)%s*%%?%s*$"))
        if val then
            value = val / 100
        else
            error(("Invalid value string (%q): must be a valid number or percentage"):format(value), 2)
        end
    elseif type(value) ~= "number" then
        error(("Invalid value: number expected, got %s"):(floof.typeOf(value)), 2)
    end
    local self_p = priv[self]
    local parent_p = priv[self_p.parent] or Element_p
    self_p.width = value
    operation(dw, self, (parent_p.w - parent_p.lp - parent_p.rp) * value - self_p.w)
    flushOperations()
end

function setters:height(value)
    if value == nil then
        self_p.height = nil
        return
    elseif type(value) == "string" then
        local val = tonumber(value:match("^%s*(%d*%.?%d+)%s*%%?%s*$"))
        if val then
            value = val / 100
        else
            error(("Invalid value string (%q): must be a valid number or percentage"):format(value), 2)
        end
    elseif type(value) ~= "number" then
        error(("Invalid value: number expected, got %s"):(floof.typeOf(value)), 2)
    end
    local self_p = priv[self]
    local parent_p = priv[self_p.parent] or Element_p
    self_p.height = value
    operation(dh, self, (parent_p.h - parent_p.tp - parent_p.bp) * value - self_p.h)
    flushOperations()
end

function setters:leftMargin(value)
    if value == nil then
        self_p.leftMargin = nil
        return
    elseif type(value) == "string" then
        local val = tonumber(value:match("^%s*(%d*%.?%d+)%s*%%?%s*$"))
        if val then
            value = val / 100
        else
            error(("Invalid value string (%q): must be a valid number or percentage"):format(value), 2)
        end
    elseif type(value) ~= "number" then
        error(("Invalid value: number expected, got %s"):(floof.typeOf(value)), 2)
    end
    local self_p = priv[self]
    self_p.leftMargin = value
    local d = self_p.w * value - self_p.lm
    if self_p.anchorX == "stretch" then`
        self_p.lm = self_p.lm + d
        operation(dx, self, d/2)
        operation(dw, self, -d)
    else
        operation(dmx, self, d, 0)
    end
    flushOperations()
end

function setters:topMargin(value)
    if value == nil then
        self_p.topMargin = nil
        return
    elseif type(value) == "string" then
        local val = tonumber(value:match("^%s*(%d*%.?%d+)%s*%%?%s*$"))
        if val then
            value = val / 100
        else
            error(("Invalid value string (%q): must be a valid number or percentage"):format(value), 2)
        end
    elseif type(value) ~= "number" then
        error(("Invalid value: number expected, got %s"):(floof.typeOf(value)), 2)
    end
    local self_p = priv[self]
    self_p.topMargin = value
    local d = self_p.h * value - self_p.tm
    if self_p.anchorY == "stretch" then`
        self_p.tm = self_p.tm + d
        operation(dy, self, d/2)
        operation(dh, self, -d)
    else
        operation(dmy, self, d, 0)
    end
    flushOperations()
end

function setters:rightMargin(value)
    if value == nil then
        self_p.rightMargin = nil
        return
    elseif type(value) == "string" then
        local val = tonumber(value:match("^%s*(%d*%.?%d+)%s*%%?%s*$"))
        if val then
            value = val / 100
        else
            error(("Invalid value string (%q): must be a valid number or percentage"):format(value), 2)
        end
    elseif type(value) ~= "number" then
        error(("Invalid value: number expected, got %s"):(floof.typeOf(value)), 2)
    end
    local self_p = priv[self]
    self_p.rightMargin = value
    local d = self_p.w * value - self_p.rm
    if self_p.anchorX == "stretch" then`
        self_p.rm = self_p.rm + d
        operation(dx, self, -d/2)
        operation(dw, self, -d)
    else
        operation(dmx, self, 0, d)
    end
    flushOperations()
end

function setters:bottomMargin(value)
    if value == nil then
        self_p.bottomMargin = nil
        return
    elseif type(value) == "string" then
        local val = tonumber(value:match("^%s*(%d*%.?%d+)%s*%%?%s*$"))
        if val then
            value = val / 100
        else
            error(("Invalid value string (%q): must be a valid number or percentage"):format(value), 2)
        end
    elseif type(value) ~= "number" then
        error(("Invalid value: number expected, got %s"):(floof.typeOf(value)), 2)
    end
    local self_p = priv[self]
    self_p.bottomMargin = value
    local d = self_p.h * value - self_p.bm
    if self_p.anchorY == "stretch" then`
        self_p.bm = self_p.bm + d
        operation(dy, self, -d/2)
        operation(dh, self, -d)
    else
        operation(dmy, self, 0, d)
    end
    flushOperations()
end

function setters:xMargin(value)
    if value == nil then
        self_p.leftMargin, self_p.rightMargin = nil
        return
    elseif type(value) == "string" then
        local val = tonumber(value:match("^%s*(%d*%.?%d+)%s*%%?%s*$"))
        if val then
            value = val / 100
        else
            error(("Invalid value string (%q): must be a valid number or percentage"):format(value), 2)
        end
    elseif type(value) ~= "number" then
        error(("Invalid value: number expected, got %s"):(floof.typeOf(value)), 2)
    end
    local self_p = priv[self]
    self_p.leftMargin, self_p.rightMargin = value, value
    local l, r = self_p.w * value - self_p.lm, self_p.w * value - self_p.rm
    if self_p.anchorX == "stretch" then
        self_p.lm, self_p.rm = self_p.lm + l, self_p.rm + r
        operation(dx, self, (l - r) / 2)
        operation(dw, self, -l - r)
    else
        operation(dmx, self, l, r)
    end
    flushOperations()
end

function setters:yMargin(value)
    if value == nil then
        self_p.topMargin, self_p.bottomMargin = nil
        return
    elseif type(value) == "string" then
        local val = tonumber(value:match("^%s*(%d*%.?%d+)%s*%%?%s*$"))
        if val then
            value = val / 100
        else
            error(("Invalid value string (%q): must be a valid number or percentage"):format(value), 2)
        end
    elseif type(value) ~= "number" then
        error(("Invalid value: number expected, got %s"):(floof.typeOf(value)), 2)
    end
    local self_p = priv[self]
    self_p.topMargin, self_p.bottomMargin = value, value
    local t, b = self_p.h * value - self_p.tm, self_p.h * value - self_p.bm
    if self_p.anchorY == "stretch" then
        self_p.tm, self_p.bm = self_p.tm + t, self_p.bm + b
        operation(dy, self, (t - b) / 2)
        operation(dh, self, -t - b)
    else
        operation(dmy, self, t, b)
    end
    flushOperations()
end

function setters:margin(value)
    if value == nil then
        self_p.leftMargin, self_p.topMargin, self_p.rightMargin, self_p.bottomMargin = nil
        return
    elseif type(value) == "string" then
        local val = tonumber(value:match("^%s*(%d*%.?%d+)%s*%%?%s*$"))
        if val then
            value = val / 100
        else
            error(("Invalid value string (%q): must be a valid number or percentage"):format(value), 2)
        end
    elseif type(value) ~= "number" then
        error(("Invalid value: number expected, got %s"):(floof.typeOf(value)), 2)
    end
    local self_p = priv[self]
    self_p.leftMargin, self_p.topMargin, self_p.rightMargin, self_p.bottomMargin = value, value, value, value
    local l, t, r, b = self_p.w * value - self_p.lm, self_p.h * value - self_p.tm, self_p.w * value - self_p.rm, self_p.h * value - self_p.bm
    if self_p.anchorX == "stretch" then
        self_p.lm, self_p.rm = self_p.lm + l, self_p.rm + r
        operation(dx, self, (l - r) / 2)
        operation(dw, self, -l - r)
    else
        operation(dmx, self, l, r)
    end
    if self_p.anchorY == "stretch" then
        self_p.tm, self_p.bm = self_p.tm + t, self_p.bm + b
        operation(dy, self, (t - b) / 2)
        operation(dh, self, -t - b)
    else
        operation(dmy, self, t, b)
    end
    flushOperations()
end

function setters:leftPadding(value)
    if value == nil then
        self_p.leftPadding = nil
        return
    elseif type(value) == "string" then
        local val = tonumber(value:match("^%s*(%d*%.?%d+)%s*%%?%s*$"))
        if val then
            value = val / 100
        else
            error(("Invalid value string (%q): must be a valid number or percentage"):format(value), 2)
        end
    elseif type(value) ~= "number" then
        error(("Invalid value: number expected, got %s"):(floof.typeOf(value)), 2)
    end
    local self_p = priv[self]
    self_p.leftPadding = value
    operation(dpx, self, self_p.w * value - self_p.lp, 0)
    flushOperations()
end

function setters:topPadding(value)
    if value == nil then
        self_p.topPadding = nil
        return
    elseif type(value) == "string" then
        local val = tonumber(value:match("^%s*(%d*%.?%d+)%s*%%?%s*$"))
        if val then
            value = val / 100
        else
            error(("Invalid value string (%q): must be a valid number or percentage"):format(value), 2)
        end
    elseif type(value) ~= "number" then
        error(("Invalid value: number expected, got %s"):(floof.typeOf(value)), 2)
    end
    local self_p = priv[self]
    self_p.topPadding = value
    operation(dpy, self, self_p.h * value - self_p.tp, 0)
    flushOperations()
end

function setters:rightPadding(value)
    if value == nil then
        self_p.rightPadding = nil
        return
    elseif type(value) == "string" then
        local val = tonumber(value:match("^%s*(%d*%.?%d+)%s*%%?%s*$"))
        if val then
            value = val / 100
        else
            error(("Invalid value string (%q): must be a valid number or percentage"):format(value), 2)
        end
    elseif type(value) ~= "number" then
        error(("Invalid value: number expected, got %s"):(floof.typeOf(value)), 2)
    end
    local self_p = priv[self]
    self_p.rightPadding = value
    operation(dpx, self, 0, self_p.w * value - self_p.rp)
    flushOperations()
end

function setters:bottomPadding(value)
    if value == nil then
        self_p.bottomPadding = nil
        return
    elseif type(value) == "string" then
        local val = tonumber(value:match("^%s*(%d*%.?%d+)%s*%%?%s*$"))
        if val then
            value = val / 100
        else
            error(("Invalid value string (%q): must be a valid number or percentage"):format(value), 2)
        end
    elseif type(value) ~= "number" then
        error(("Invalid value: number expected, got %s"):(floof.typeOf(value)), 2)
    end
    local self_p = priv[self]
    self_p.bottomPadding = value
    operation(dpy, self, 0, self_p.h * value - self_p.bp)
    flushOperations()
end

function setters:xPadding(value)
    if value == nil then
        self_p.leftPadding, self_p.rightPadding = nil
        return
    elseif type(value) == "string" then
        local val = tonumber(value:match("^%s*(%d*%.?%d+)%s*%%?%s*$"))
        if val then
            value = val / 100
        else
            error(("Invalid value string (%q): must be a valid number or percentage"):format(value), 2)
        end
    elseif type(value) ~= "number" then
        error(("Invalid value: number expected, got %s"):(floof.typeOf(value)), 2)
    end
    local self_p = priv[self]
    self_p.leftPadding, self_p.rightPadding = value, value
    operation(dpx, self, self_p.w * value - self_p.lp, self_p.w * value - self_p.rp)
    flushOperations()
end

function setters:yPadding(value)
    if value == nil then
        self_p.topPadding, self_p.bottomPadding = nil
        return
    elseif type(value) == "string" then
        local val = tonumber(value:match("^%s*(%d*%.?%d+)%s*%%?%s*$"))
        if val then
            value = val / 100
        else
            error(("Invalid value string (%q): must be a valid number or percentage"):format(value), 2)
        end
    elseif type(value) ~= "number" then
        error(("Invalid value: number expected, got %s"):(floof.typeOf(value)), 2)
    end
    local self_p = priv[self]
    self_p.topPadding, self_p.bottomPadding = value, value
    operation(dpy, self, self_p.h * value - self_p.tp, self_p.h * value - self_p.bp)
    flushOperations()
end

function setters:padding(value)
    if value == nil then
        self_p.leftPadding, self_p.topPadding, self_p.rightPadding, self_p.bottomPadding = nil
        return
    elseif type(value) == "string" then
        local val = tonumber(value:match("^%s*(%d*%.?%d+)%s*%%?%s*$"))
        if val then
            value = val / 100
        else
            error(("Invalid value string (%q): must be a valid number or percentage"):format(value), 2)
        end
    elseif type(value) ~= "number" then
        error(("Invalid value: number expected, got %s"):(floof.typeOf(value)), 2)
    end
    local self_p = priv[self]
    self_p.leftPadding, self_p.topPadding, self_p.rightPadding, self_p.bottomPadding = value, value, value, value
    local l, t, r, b = self_p.w * value - self_p.lp, self_p.h * value - self_p.tp, self_p.w * value - self_p.rp, self_p.h * value - self_p.bp
    operation(dpx, self, l, r)
    operation(dpy, self, t, b)
    flushOperations()
end

function setters:spacing(value)
    if value == nil then
        self_p.spacing = nil
        return
    elseif type(value) == "string" then
        local val = tonumber(value:match("^%s*(%d*%.?%d+)%s*%%?%s*$"))
        if val then
            value = val / 100
        else
            error(("Invalid value string (%q): must be a valid number or percentage"):format(value), 2)
        end
    elseif type(value) ~= "number" then
        error(("Invalid value: number expected, got %s"):(floof.typeOf(value)), 2)
    end
    local self_p = priv[self]
    self_p.spacing = value
    local b
    if self_p.layoutDirection == "row" then
        b = self_p.w - self_p.lp - self_p.rp
    elseif self_p.layoutDirection == "column" then
        b = self_p.h - self_p.tp - self_p.bp
    end
    operation(ds, self, b * value - self_p.space)
    flushOperations()
end

-- sorting order

function isBefore(self, other)
    validateElement(self, "caller")
    validateElement(other, "value")
    local self_p, other_p = priv[self], priv[other]
    if self_p.parentElement ~= other_p.parentElement then
        error("Invalid value: must be an Element sibling of the caller", 2)
    end
    return before[self][other] or false
end
Element.isBefore = isBefore

function setSortOrder(self, priority)
    validateElement(self, "caller")
    if type(priority) ~= "number" then
        error(("Invalid value: number expected, got %s"):format(floof.typeOf(priority)), 2)
    end
    local self_p = priv[self]
    self_p.sortingPriority = priority
    local parent_p = priv[parent]
    local pos  = parent_p.layoutDirection == "row" and "x"  or "y"
    local size = parent_p.layoutDirection == "row" and "w"  or "h"
    local m1   = parent_p.layoutDirection == "row" and "lm" or "tm"
    local m2   = parent_p.layoutDirection == "row" and "rm" or "bm"
    local move = parent_p.layoutDirection == "row" and  dx  or  dy
    local moveself = 0
    if self_p.nextElement and priv[self_p.nextElement].sortingPriority > priority then
        for sib in iterateElement(self) do
            local sib_p = priv[sib]
            if sib_p.sortingPriority < priority then break end
            self_p.nextElement, sib_p.previousElement = sib_p.nextElement, self_p.previousElement
            if sib_p.nextElement then
                priv[sib_p.nextElement].previousElement = self
            else
                parent_p.frontmost = self
            end
            if self_p.previousElement then
                priv[self_p.previousElement].nextElement = sib
            else
                parent_p.backmost = sib
            end
            sib_p.nextElement, self_p.previousElement = self, sib
            before[sib][self], before[self][sib] = true
            if self_p.inLayout and sib_p.inLayout then
                if self_p.layoutIndex then
                    operation(move, sib, -self_p[size] - self_p[m1] - self_p[m2] - parent_p.space - parent_p.extraSpace)
                end
                if sib_p.layoutIndex then
                    moveself = moveself + sib_p[size] + sib_p[m1] + sib_p[m2] + parent_p.space + parent_p.extraSpace
                end
                if self_p.layoutIndex and sib_p.layoutIndex then
                    self_p.layoutIndex = self_p.layoutIndex + 1
                    sib_p.layoutIndex = sib_p.layoutIndex - 1
                end
            end
        end
    elseif self_p.previousElement and priv[self_p.previousElement].sortingPriority < priority then
        for sib in backtrackElement(self) do
            local sib_p = priv[sib]
            if sib_p.sortingPriority > priority then break end
            sib_p.nextElement, self_p.previousElement = self_p.nextElement, sib_p.previousElement
            if self_p.nextElement then
                priv[self_p.nextElement].previousElement = sib
            else
                parent_p.frontmost = sib
            end
            if sib_p.previousElement then
                priv[sib_p.previousElement].nextElement = self
            else
                parent_p.backmost = self
            end
            self_p.nextElement, sib_p.previousElement = sib, self
            before[self][sib], before[sib][self] = true
            if self_p.inLayout and sib_p.inLayout then
                if self_p.layoutIndex then
                    operation(move, sib, self_p[size] + self_p[m1] + self_p[m2] + parent_p.space + parent_p.extraSpace)
                end
                if sib_p.layoutIndex then
                    moveself = moveself - sib_p[size] - sib_p[m1] - sib_p[m2] - parent_p.space - parent_p.extraSpace
                end
                if self_p.layoutIndex and sib_p.layoutIndex then
                    self_p.layoutIndex = self_p.layoutIndex - 1
                    sib_p.layoutIndex = sib_p.layoutIndex + 1
                end
            end
        end
    end
    operation(move, self, moveself)
    if initialized[self] then
        floof.safeInvoke(Object.invokeHandlers, self, "reordered")
        handleCallback(self, "reordered")
    end
end
Element.setSortOrder, setters.sortingPriority = setSortOrder, setSortOrder

function moveBefore(self, nxt)
    validateElement(self, "caller")
    if nxt ~= nil then validateElement(nxt, "value") end
    if self == nxt then error("Invalid value: equal to caller", 2) end
    local self_p, nxt_p = priv[self], priv[nxt]
    if nxt and nxt_p.parentElement ~= self_p.parentElement then
        error("Invalid value: must be an Element sibling of the caller", 2)
    end
    if self_p.nextElement == nxt then return end
    local parent_p = priv[self_p.parentElement] or Element_p
    local pos  = parent_p.layoutDirection == "row" and "x"  or "y"
    local size = parent_p.layoutDirection == "row" and "w"  or "h"
    local m1   = parent_p.layoutDirection == "row" and "lm" or "tm"
    local m2   = parent_p.layoutDirection == "row" and "rm" or "bm"
    local move = parent_p.layoutDirection == "row" and  dx  or  dy
    local moveself = 0
    if before[self][nxt] then

    else

    end
end
Element.moveBefore, setters.nextElement = moveBefore, moveBefore

function moveAfter(self, prv)
    validateElement(self, "caller")
    if prv ~= nil then validateElement(prv, "value") end
    if self == prv then error("Invalid value: equal to caller", 2) end
    local self_p, prv_p = priv[self], priv[prv]
    if prv and prv_p.parent ~= self_p.parentElement then
        error("Invalid value: must be an Element sibling of the caller", 2)
    end
    if self_p.previousElement == prv then return end
    local parent_p = priv[self_p.parentElement] or Element_p
    local pos  = parent_p.layoutDirection == "row" and "x"  or "y"
    local size = parent_p.layoutDirection == "row" and "w"  or "h"
    local m1   = parent_p.layoutDirection == "row" and "lm" or "tm"
    local m2   = parent_p.layoutDirection == "row" and "rm" or "bm"
    local move = parent_p.layoutDirection == "row" and  dx  or  dy
    local moveself = 0
    if before[self][nxt] then

    else

    end
end
Element.moveAfter, setters.backward = moveBehind, moveBehind

function setFirstChild(self, first)
    validateObject(self, "caller", true)
    validateObject(first, "value")
    local self_p, first_p = priv[self], priv[first]
    if first_p.parentElement ~= self then
        error("Invalid value: object must be an Element child of the caller", 2)
    end
    if self_p.firstChildElement == first then return end
    floof.safeInvoke(moveBefore, first, self_p.firstChildElement)
end
Element.setFirstChild, setters.firstChildElement = setFirstChild, setFirstChild

function setLastChild(self, last)
    validateObject(self, "caller", true)
    validateObject(last, "value")
    local self_p, last_p = priv[self], priv[last]
    if last_p.parentElement ~= self then
        error("Invalid value: object must be an Element child of the caller", 2)
    end
    if self_p.lastChildElement == last then return end
    floof.safeInvoke(moveAfter, last, self_p.lastChildElement)
end
Element.setLastChild, setters.lastChildElement = setLastChild, setLastChild

-- iterators

elementAncestors = privKeyIterator("parentElement")
Element.elementAncestors = elementAncestors

iterateElement, backtrackElement = privKeyIterator("nextElement"), privKeyIterator("previousElement")
Element.iterateElement, Element.backtrackElement = iterateElement, backtrackElement

function iterateElementChildren(self)
    if priv[self] then
        return iterateElement(priv[self].firstChildElement, true)
    else
        return rawget, {}
    end
end
function backtrackElementChildren(self)
    if priv[self] then
        return backtrackElement(priv[self].lastChildElement, true)
    else
        return rawget, {}
    end
end
Element.iterateElementChildren, Element.backtrackElementChildren = iterateElementChildren, backtrackElementChildren

function nextElementInHierarchy(self, start)
    if not priv[self] then return end
    if priv[self].firstChildElement then return priv[self].firstChildElement end
    for obj in elementAncestors(self) do
        if obj == start then return end
        if priv[obj].nextElement then return priv[obj].nextElement end
    end
end
function previousElementInHierarchy(self, start)
    if not priv[self] then return end
    if priv[self].lastChildElement then return priv[self].lastChildElement end
    for obj in elementAncestors(self) do
        if obj == start then return end
        if priv[obj].previousElement then return priv[obj].previousElement end
    end
end
iterateElementHierarchy, backtrackElementHierarchy = floof.newIterator(nextElementInHierarchy), floof.newIterator(previousElementInHierarchy)
Element.iterateElementHierarchy, Element.backtrackElementHierarchy = iterateElementHierarchy, backtrackElementHierarchy

return Element