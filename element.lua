-- FLOOF: Fast Lua Element-Oriented Framework
-- Copyright (c) 2026 Matus Kordos

local PATH = (...):match("^(.*%.).-$") or ""
local floof = require(PATH)
local array, vec, Object = floof.array, floof.vector, floof.object

local Element = Object:class("Element")

-- function pre-defs

local dx, dy,
      dw, dh,
      dmx, dmy,
      dpx, dpy,
      ds, droom,
      anchor

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
    x  = 0, y  = 0, w  = 0, h  = 0,
    l  = 0, t  = 0, r  = 0, b  = 0,
    lp = 0, tp = 0, rp = 0, bp = 0,
    leftPadding = nil, topPadding = nil, rightPadding = nil, bottomPadding = nil,
    layoutDirection = "column", justifyChildren = "top", alignChildren = "center",
    space = 0, spacing = nil, spaceAround = false, expandSpace = false, extraRoom = 0, totalSpace = 0,
    firstChildElement = nil, lastChildElement = nil, layoutCount = 0,
    layoutContentSize = 0, scroll = 0, minScroll = 0, maxScroll = 0
}
local priv = setmetatable({[Element] = Element_p}, {__mode = "k"})
local initialized    = setmetatable({}, {__mode = "k"})
local firstActivated = setmetatable({}, {__mode = "k"})
local active         = setmetatable({}, {__mode = "k"})
local before         = setmetatable({}, {__mode = "k"})
local deleted        = setmetatable({}, {__mode = "k"})

local function initPrivInstance(self)
    local p = {
        parentElement = nil,
        previousElement = nil, nextElement = nil, sortingPriority = 0,
        x  = 0, y  = 0, w  = 0, h  = 0,
        l  = 0, t  = 0, r  = 0, b  = 0,
        lm = 0, tm = 0, rm = 0, bm = 0,
        lp = 0, tp = 0, rp = 0, bp = 0,
        width = nil, height = nil,
        alignX = nil, alignY = nil, anchorX = "center", anchorY = "center",
        leftMargin  = nil, topMargin  = nil, rightMargin  = nil, bottomMargin  = nil,
        leftPadding = nil, topPadding = nil, rightPadding = nil, bottomPadding = nil,
        inLayout = true, layoutIndex = nil, offsetX = 0, offsetY = 0, lockedX = false, lockedY = false,
        layoutDirection = "column", justifyChildren = "top", alignChildren = "center",
        space = 0, spacing = nil, spaceAround = false, expandSpace = false, extraRoom = 0,
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
    width = priv, height = priv,
    alignX = priv, alignY = priv, --anchorX = priv, anchorY = priv,
    leftMargin  = priv, topMargin  = priv, rightMargin  = priv, bottomMargin  = priv,
    leftPadding = priv, topPadding = priv, rightPadding = priv, bottomPadding = priv,
    inLayout = priv, layoutIndex = priv, offsetX = priv, offsetY = priv, lockedX = priv, lockedY = priv,
    layoutDirection = priv, justifyChildren = priv, alignChildren = priv,
    space = priv, spacing = priv, spaceAround = priv, expandSpace = priv, totalSpace = priv, extraRoom = priv,
    firstChildElement = priv, lastChildElement = priv, layoutCount = priv,
    layoutContentSize = priv, scroll = priv, minScroll = priv, maxScroll = priv
}
function Element:__get(k)
    if priv[self] then
        if type(k) == "number" then
            if k < 0 then k = k + priv[self].layoutCount + 1 end
            for elem in iterateElementChildren(self) do
                if priv[elem].layoutIndex == k then return elem end
            end
        elseif getters[k] then
            if getters[k] == priv then
                return priv[self][k]
            else
                return floof.safeReturn(getters[k], self)
            end
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
            return floof.safeReturn(setters[k], self, v)
        end
    else return floof.set(Object, self, k, v) end
end

function Element:check(x, y)
    local self_p = priv[self]
    return self_p and x >= self_p.l and y >= self_p.t and x <= self_p.r and y <= self_p.b
end

-- positioning logic

local operations = {}
local dirty, clean

function operation(f, ...)
    local op = {func = f, ...}
    if operations.tail then
        operations[operations.tail], operations.tail = op, op
    else
        operations.head, operations.tail = op, op
    end
end

function flushOperations()
    if operations.running or not operations.head then return end
    operations.running = true
    dirty, clean = {}, {}
    while operations.head do
        local op = operations.head
        local s, e = pcall(op.func, unpack(op))
        if not s then error(e, 3) end
        if operations[op] then
            operations.head, operations[op] = operations[op]
        else
            operations.head, operations.tail = nil
            for el in pairs(dirty) do
                if not clean[el] then
                    local s, e = pcall(Object.shapeChanged, el)
                    if not s then error(e, 3) end
                    clean[el] = true
                end
            end
        end
    end
    operations.running = false
end

function dx(self, d, offset)
    if d == 0 then return end
    local self_p = priv[self]
    if self_p.lockedX and not offset then
        self_p.offsetX = self_p.offsetX - d
        return
    end
    self_p.x = self_p.x + d
    self_p.l = self_p.l + d
    self_p.r = self_p.r + d
    if offset then self_p.offsetX = self_p.offsetX + d end
    for elem in iterateElementChildren(self) do
        operation(dx, elem, d)
    end
    if self ~= Element then dirty[self] = true end
end

function dy(self, d, offset)
    if d == 0 then return end
    local self_p = priv[self]
    if self_p.lockedY and not offset then
        self_p.offsetY = self_p.offsetY - d
        return
    end
    self_p.y = self_p.y + d
    self_p.t = self_p.t + d
    self_p.b = self_p.b + d
    if offset then self_p.offsetY = self_p.offsetY + d end
    for elem in iterateElementChildren(self) do
        operation(dy, elem, d)
    end
    if self ~= Element then dirty[self] = true end
end

function dw(self, d)
    if d == 0 then return end
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
        if self_p.anchorX == "left" or self == Element then
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
    if self_p.layoutIndex and parent_p.layoutDirection == "row" then operation(droom, self_p.parentElement or Element, -d) end
    if self_p.layoutDirection == "row" then operation(droom, self, d) end
    if self ~= Element then dirty[self] = true end
end

function dh(self, d)
    if d == 0 then return end
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
        if self_p.anchorY == "top" or self == Element then
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
    if self_p.layoutIndex and parent_p.layoutDirection == "column" then operation(droom, self_p.parentElement or Element, -d) end
    if self_p.layoutDirection == "column" then operation(droom, self, d) end
    if self ~= Element then dirty[self] = true end
end

function dmx(self, l, r)
    if l == 0 and r == 0 then return end
    local self_p = priv[self]
    local parent_p = priv[self_p.parentElement] or Element_p
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
            for sib in backtrackElement(self) do
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
    if self_p.layoutIndex and parent_p.layoutDirection == "row" then operation(droom, self_p.parentElement or Element, -d) end
end

function dmy(self, t, b)
    if t == 0 and b == 0 then return end
    local self_p = priv[self]
    local parent_p = priv[self_p.parentElement] or Element_p
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
            for sib in backtrackElement(self) do
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
    if self_p.layoutIndex and parent_p.layoutDirection == "column" then operation(droom, self_p.parentElement or Element, -d) end
end

function dpx(self, l, r)
    if l == 0 and r == 0 then return end
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
    if self_p.layoutDirection == "row" then operation(droom, self, -d) end
end

function dpy(self, t, b)
    if t == 0 and b == 0 then return end
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
    if self_p.layoutDirection == "column" then operation(droom, self, -d) end
end

function ds(self, d, room)
    if d == 0 then return end
    local self_p = priv[self]
    self_p.totalSpace = self_p.totalSpace + d
    local tr
    if self_p.justifyChildren == "left" or self_p.justifyChildren == "top" then
        tr = self_p.spaceAround and d or 0
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
    if not room then
        self_p.space = self_p.space + d
        operation(droom, self, -d * math.max(self_p.layoutCount + (self_p.spaceAround and 1 or -1), 0))
    end
end

function droom(self, d)
    if d == 0 then return end
    local self_p = priv[self]
    local dr = math.max(self_p.extraRoom + d, 0) - math.max(self_p.extraRoom, 0)
    local ns = math.max(self_p.layoutCount + (self_p.spaceAround and 1 or -1), 0)
    self_p.extraRoom = self_p.extraRoom + d
    local scr = 0
    if self_p.justifyChildren == "left" or self_p.justifyChildren == "top" then
        self_p.minScroll, self_p.maxScroll = math.min(self_p.extraRoom, 0), 0
    elseif self_p.justifyChildren == "center" or self_p.justifyChildren == "middle" then
        self_p.minScroll, self_p.maxScroll = math.min(self_p.extraRoom/2, 0), math.max(-self_p.extraRoom/2, 0)
    elseif self_p.justifyChildren == "right" or self_p.justifyChildren == "bottom" then
        self_p.minScroll, self_p.maxScroll = 0, math.max(-self_p.extraRoom, 0)
    end
    if self_p.scroll < self_p.minScroll then
        scr = self_p.minScroll - self_p.scroll
        self_p.scroll = self_p.minScroll
    elseif self_p.scroll > self_p.maxScroll then
        scr = self_p.maxScroll - self_p.scroll
        self_p.scroll = self_p.maxScroll
    end
    if self_p.expandSpace and ns > 0 then
        operation(ds, self, dr / ns, true)
    end
    for elem in iterateElementChildren(self) do
        local elem_p = priv[elem]
        if elem_p.inLayout and scr ~= 0 then
            if self_p.layoutDirection == "row" then
                operation(dx, elem, scr)
            elseif self_p.layoutDirection == "column" then
                operation(dy, elem, scr)
            end
        end
    end
end

function anchor(self, alreadyActive)
    local self_p = priv[self]
    local parent_p = priv[self_p.parentElement] or Element_p
    local x, y = 0, 0
    if self_p.inLayout and parent_p.justifyChildren == "left" then
        self_p.anchorX = "left"
        x = parent_p.l + parent_p.lp + parent_p.scroll +
            (parent_p.spaceAround and parent_p.totalSpace * (alreadyActive and 1 or 0.5) or 0) -
            (alreadyActive and self_p.l - self_p.lm or self_p.x) + self_p.offsetX
        for sib in backtrackElement(self) do
            local sib_p = priv[sib]
            if sib_p.layoutIndex then
                x = x + sib_p.lm + sib_p.w + sib_p.rm + parent_p.totalSpace
            end
        end
    elseif self_p.inLayout and parent_p.justifyChildren == "center" then
        self_p.anchorX = "center"
        x = parent_p.x + parent_p.scroll + self_p.offsetX
        for sib in backtrackElement(self) do
            local sib_p = priv[sib]
            if sib_p.layoutIndex then
                x = x + (sib_p.lm + sib_p.w + sib_p.rm + parent_p.totalSpace) / 2
            end
        end
        for sib in iterateElement(self) do
            local sib_p = priv[sib]
            if sib_p.layoutIndex then
                x = x - (sib_p.lm + sib_p.w + sib_p.rm + parent_p.totalSpace) / 2
            end
        end
    elseif self_p.inLayout and parent_p.justifyChildren == "right" then
        self_p.anchorX = "right"
        x = parent_p.r - parent_p.rp + parent_p.scroll -
            (parent_p.spaceAround and parent_p.totalSpace * (alreadyActive and 1 or 0.5) or 0) -
            (alreadyActive and self_p.r - self_p.rm or self_p.x) + self_p.offsetX
        for sib in iterateElement(self) do
            local sib_p = priv[sib]
            if sib_p.layoutIndex then
                x = x - (sib_p.lm + sib_p.w + sib_p.rm + parent_p.totalSpace)
            end
        end
    elseif (self_p.alignX or self_p.inLayout and parent_p.alignChildren) == "left" then
        self_p.anchorX = "left"
        x = parent_p.l + parent_p.lp + self_p.offsetX - self_p.l + self_p.lm
    elseif (self_p.alignX or self_p.inLayout and parent_p.alignChildren) == "center" or (not self_p.inLayout and not self_p.alignX) then
        self_p.anchorX = "center"
        x = parent_p.x + self_p.offsetX - self_p.x
    elseif (self_p.alignX or self_p.inLayout and parent_p.alignChildren) == "right" then
        self_p.anchorX = "right"
        x = parent_p.r - parent_p.rp + self_p.offsetX - self_p.r - self_p.rm
    elseif (self_p.alignX or self_p.inLayout and parent_p.alignChildren) == "stretch" then
        self_p.anchorX = "stretch"
        x = parent_p.x + self_p.offsetX + (self_p.lm - self_p.rm) / 2 - self_p.x
        operation(dw, self, parent_p.w - parent_p.lp - parent_p.rp - self_p.w - self_p.lm - self_p.rm)
    end
    if self_p.inLayout and parent_p.justifyChildren == "top" then
        self_p.anchorY = "top"
        y = parent_p.t + parent_p.tp + parent_p.scroll +
            (parent_p.spaceAround and parent_p.totalSpace * (alreadyActive and 1 or 0.5) or 0) -
            (alreadyActive and self_p.t - self_p.tm or self_p.y) + self_p.offsetY
        for sib in backtrackElement(self) do
            local sib_p = priv[sib]
            if sib_p.layoutIndex then
                y = y + sib_p.tm + sib_p.h + sib_p.bm + parent_p.totalSpace
            end
        end
    elseif self_p.inLayout and parent_p.justifyChildren == "middle" then
        self_p.anchorY = "middle"
        y = parent_p.y + parent_p.scroll + self_p.offsetY
        for sib in backtrackElement(self) do
            local sib_p = priv[sib]
            if sib_p.layoutIndex then
                y = y + (sib_p.tm + sib_p.h + sib_p.bm + parent_p.totalSpace) / 2
            end
        end
        for sib in iterateElement(self) do
            local sib_p = priv[sib]
            if sib_p.layoutIndex then
                y = y - (sib_p.tm + sib_p.h + sib_p.bm + parent_p.totalSpace) / 2
            end
        end
    elseif self_p.inLayout and parent_p.justifyChildren == "bottom" then
        self_p.anchorY = "bottom"
        y = parent_p.b - parent_p.bp + parent_p.scroll -
            (parent_p.spaceAround and parent_p.totalSpace * (alreadyActive and 1 or 0.5) or 0) -
            (alreadyActive and self_p.b - self_p.bm or self_p.x) + self_p.offsetY
        for sib in iterateElement(self) do
            local sib_p = priv[sib]
            if sib_p.layoutIndex then
                y = y - (sib_p.tm + sib_p.h + sib_p.bm + parent_p.totalSpace)
            end
        end
    elseif (self_p.alignY or self_p.inLayout and parent_p.alignChildren) == "top" then
        self_p.anchorY = "top"
        y = parent_p.t + parent_p.tp + self_p.offsetY - self_p.t + self_p.tm
    elseif (self_p.alignY or self_p.inLayout and parent_p.alignChildren) == "middle" or (not self_p.inLayout and not self_p.alignY) then
        self_p.anchorY = "middle"
        y = parent_p.y + self_p.offsetY - self_p.y
    elseif (self_p.alignY or self_p.inLayout and parent_p.alignChildren) == "bottom" then
        self_p.anchorY = "bottom"
        y = parent_p.b - parent_p.bp + self_p.offsetY - self_p.b - self_p.bm
    elseif (self_p.alignY or self_p.inLayout and parent_p.alignChildren) == "expand" then
        self_p.anchorY = "expand"
        y = parent_p.y + self_p.offsetY + (self_p.tm - self_p.bm) / 2 - self_p.y
        operation(dh, self, parent_p.h - parent_p.tp - parent_p.bp - self_p.h - self_p.tm - self_p.bm)
    end
    operation(dx, self, x)
    operation(dy, self, y)
end

local function addToLayout(self)
    local self_p = priv[self]
    local parent_p = priv[self_p.parentElement] or Element_p
    if parent_p.justifyChildren == "left" then
        operation(dx, self, ((parent_p.layoutCount > 0 or parent_p.spaceAround) and  parent_p.totalSpace/2 or 0) + self_p.lm + self_p.w/2)
    elseif parent_p.justifyChildren == "center" then
        operation(dx, self, self_p.lm/2 - self_p.rm/2)
    elseif parent_p.justifyChildren == "right" then
        operation(dx, self, ((parent_p.layoutCount > 0 or parent_p.spaceAround) and -parent_p.totalSpace/2 or 0) - self_p.rm - self_p.w/2)
    elseif parent_p.justifyChildren == "top" then
        operation(dy, self, ((parent_p.layoutCount > 0 or parent_p.spaceAround) and  parent_p.totalSpace/2 or 0) + self_p.tm + self_p.h/2)
    elseif parent_p.justifyChildren == "middle" then
        operation(dy, self, self_p.tm/2 - self_p.bm/2)
    elseif parent_p.justifyChildren == "bottom" then
        operation(dy, self, ((parent_p.layoutCount > 0 or parent_p.spaceAround) and -parent_p.totalSpace/2 or 0) - self_p.bm - self_p.h/2)
    end
    local index = 1
    for sib in backtrackElement(self) do
        local sib_p = priv[sib]
        if sib_p.layoutIndex then index = index + 1 end
        if sib_p.inLayout then
            if parent_p.justifyChildren == "center" then
                operation(dx, sib, (parent_p.layoutCount > 0 and -parent_p.totalSpace/2 or 0) - self_p.lm/2 - self_p.w/2 - self_p.rm/2)
            elseif parent_p.justifyChildren == "right" then
                operation(dx, sib, (parent_p.layoutCount > 0 and -parent_p.totalSpace   or 0) - self_p.lm   - self_p.w   - self_p.rm  )
            elseif parent_p.justifyChildren == "middle" then
                operation(dy, sib, (parent_p.layoutCount > 0 and -parent_p.totalSpace/2 or 0) - self_p.tm/2 - self_p.h/2 - self_p.bm/2)
            elseif parent_p.justifyChildren == "bottom" then
                operation(dy, sib, (parent_p.layoutCount > 0 and -parent_p.totalSpace   or 0) - self_p.tm   - self_p.h   - self_p.bm  )
            end
        end
    end
    self_p.layoutIndex = index
    for sib in iterateElement(self) do
        local sib_p = priv[sib]
        if sib_p.layoutIndex then sib_p.layoutIndex = sib_p.layoutIndex + 1 end
        if sib_p.inLayout then
            if parent_p.justifyChildren == "left" then
                operation(dx, sib, (parent_p.layoutCount > 0 and parent_p.totalSpace   or 0) + self_p.lm   + self_p.w   + self_p.rm  )
            elseif parent_p.justifyChildren == "center" then
                operation(dx, sib, (parent_p.layoutCount > 0 and parent_p.totalSpace/2 or 0) + self_p.lm/2 + self_p.w/2 + self_p.rm/2)
            elseif parent_p.justifyChildren == "top" then
                operation(dy, sib, (parent_p.layoutCount > 0 and parent_p.totalSpace   or 0) + self_p.tm   + self_p.h   + self_p.bm  )
            elseif parent_p.justifyChildren == "middle" then
                operation(dy, sib, (parent_p.layoutCount > 0 and parent_p.totalSpace/2 or 0) + self_p.tm/2 + self_p.h/2 + self_p.bm/2)
            end
        end
    end
    parent_p.layoutCount = parent_p.layoutCount + 1
    local dr
    if parent_p.layoutDirection == "row" then
        dr = -self_p.lm - self_p.w - self_p.rm
    elseif parent_p.layoutDirection == "column" then
        dr = -self_p.tm - self_p.h - self_p.bm
    end
    local ns = parent_p.layoutCount + (parent_p.spaceAround and 1 or -1)
    if ns > 0 then
        operation(ds, self_p.parentElement or Element, math.max(parent_p.extraRoom, 0) / ns - parent_p.totalSpace + parent_p.space, true)
    end
    operation(droom, self_p.parentElement or Element, dr)
end

local function removeFromLayout(self)
    local self_p = priv[self]
    self_p.layoutIndex = nil
    local parent_p = priv[self_p.parentElement] or Element_p
    parent_p.layoutCount = parent_p.layoutCount - 1
    if parent_p.justifyChildren == "left" then
        operation(dx, self, (parent_p.layoutCount > 0 and -parent_p.totalSpace/2 or 0) - self_p.lm - self_p.w/2)
    elseif parent_p.justifyChildren == "center" then
        operation(dx, self, self_p.rm/2 - self_p.lm/2)
    elseif parent_p.justifyChildren == "right" then
        operation(dx, self, (parent_p.layoutCount > 0 and  parent_p.totalSpace/2 or 0) + self_p.rm + self_p.w/2)
    elseif parent_p.justifyChildren == "top" then
        operation(dy, self, (parent_p.layoutCount > 0 and -parent_p.totalSpace/2 or 0) - self_p.tm - self_p.h/2)
    elseif parent_p.justifyChildren == "middle" then
        operation(dy, self, self_p.bm/2 - self_p.tm/2)
    elseif parent_p.justifyChildren == "bottom" then
        operation(dy, self, (parent_p.layoutCount > 0 and  parent_p.totalSpace/2 or 0) + self_p.bm + self_p.h/2)
    end
    for sib in backtrackElement(self) do
        local sib_p = priv[sib]
        if sib_p.inLayout then
            if parent_p.justifyChildren == "center" then
                operation(dx, sib, (parent_p.layoutCount > 0 and parent_p.totalSpace/2 or 0) + self_p.lm/2 + self_p.w/2 + self_p.rm/2)
            elseif parent_p.justifyChildren == "right" then
                operation(dx, sib, (parent_p.layoutCount > 0 and parent_p.totalSpace   or 0) + self_p.lm   + self_p.w   + self_p.rm  )
            elseif parent_p.justifyChildren == "middle" then
                operation(dy, sib, (parent_p.layoutCount > 0 and parent_p.totalSpace/2 or 0) + self_p.tm/2 + self_p.h/2 + self_p.bm/2)
            elseif parent_p.justifyChildren == "bottom" then
                operation(dy, sib, (parent_p.layoutCount > 0 and parent_p.totalSpace   or 0) + self_p.tm   + self_p.h   + self_p.bm  )
            end
        end
    end
    for sib in iterateElement(self) do
        local sib_p = priv[sib]
        if sib_p.layoutIndex then sib_p.layoutIndex = sib_p.layoutIndex - 1 end
        if sib_p.inLayout then
            if parent_p.justifyChildren == "left" then
                operation(dx, sib, (parent_p.layoutCount > 0 and -parent_p.totalSpace   or 0) - self_p.lm   - self_p.w   - self_p.rm  )
            elseif parent_p.justifyChildren == "center" then
                operation(dx, sib, (parent_p.layoutCount > 0 and -parent_p.totalSpace/2 or 0) - self_p.lm/2 - self_p.w/2 - self_p.rm/2)
            elseif parent_p.justifyChildren == "top" then
                operation(dy, sib, (parent_p.layoutCount > 0 and -parent_p.totalSpace   or 0) - self_p.tm   - self_p.h   - self_p.bm  )
            elseif parent_p.justifyChildren == "middle" then
                operation(dy, sib, (parent_p.layoutCount > 0 and -parent_p.totalSpace/2 or 0) - self_p.tm/2 - self_p.h/2 - self_p.bm/2)
            end
        end
    end
    local dr
    if parent_p.layoutDirection == "row" then
        dr = self_p.lm + self_p.w + self_p.rm
    elseif parent_p.layoutDirection == "column" then
        dr = self_p.tm + self_p.h + self_p.bm
    end
    local ns = parent_p.layoutCount + (parent_p.spaceAround and 1 or -1)
    if ns > 0 then
        operation(ds, self_p.parentElement or Element, math.max(parent_p.extraRoom, 0) / ns - parent_p.totalSpace + parent_p.space, true)
    end
    operation(droom, self_p.parentElement or Element, dr)
end

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
    if not firstActivated[self] then firstActivated[self] = true end
    active[self] = true
    if self_p.inLayout then
        addToLayout(self)
        flushOperations()
    end
end)

Element:registerHandler("deactivated", function(self)
    local self_p = priv[self]
    active[self] = nil
    if self_p.inLayout then
        removeFromLayout(self)
        flushOperations()
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
    for sib in backtrackElement(self) do before[sib][self] = true end
    if self_p.inLayout and active[self] and firstActivated[self] then
        addToLayout(self)
    end
    operation(anchor, self)
    flushOperations()
end

local function removed(self, parent)
    local self_p = priv[self]
    if self_p.inLayout and active[self] then
        removeFromLayout(self)
    end
    flushOperations()
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
    deleted[self] = true
end)

Object.registerHandler("resize", function(w, h)
    operation(dw, Element, w - Element_p.w)
    operation(dh, Element, h - Element_p.h)
    flushOperations()
end)

-- properties

function setters:x(value)
    validateElement(self, "self", false)
    if type(value) ~= "number" then
        error(("Invalid value: number expected, got %s"):format(floof.typeOf(value)), 2)
    end
    local self_p = priv[self]
    operation(dx, self, value - self_p.x, true)
    flushOperations()
end

function setters:y(value)
    validateElement(self, "self", false)
    if type(value) ~= "number" then
        error(("Invalid value: number expected, got %s"):format(floof.typeOf(value)), 2)
    end
    local self_p = priv[self]
    operation(dy, self, value - self_p.y, true)
    flushOperations()
end

function setters:w(value)
    validateElement(self, "self", true)
    if type(value) ~= "number" then
        error(("Invalid value: number expected, got %s"):format(floof.typeOf(value)), 2)
    end
    local self_p = priv[self]
    if self_p.width then error("Cannot modify the raw width of an Element with dynamic width", 2) end
    operation(dw, self, value - self_p.w)
    flushOperations()
end

function setters:h(value)
    validateElement(self, "self", true)
    if type(value) ~= "number" then
        error(("Invalid value: number expected, got %s"):format(floof.typeOf(value)), 2)
    end
    local self_p = priv[self]
    if self_p.height then error("Cannot modify the raw height of an Element with dynamic height", 2) end
    operation(dh, self, value - self_p.h)
    flushOperations()
end

function setters:l(value)
    validateElement(self, "self", false)
    if type(value) ~= "number" then
        error(("Invalid value: number expected, got %s"):format(floof.typeOf(value)), 2)
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
    validateElement(self, "self", false)
    if type(value) ~= "number" then
        error(("Invalid value: number expected, got %s"):format(floof.typeOf(value)), 2)
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
    validateElement(self, "self", false)
    if type(value) ~= "number" then
        error(("Invalid value: number expected, got %s"):format(floof.typeOf(value)), 2)
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
    validateElement(self, "self", false)
    if type(value) ~= "number" then
        error(("Invalid value: number expected, got %s"):format(floof.typeOf(value)), 2)
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
    validateElement(self, "self", false)
    if type(value) ~= "number" then
        error(("Invalid value: number expected, got %s"):format(floof.typeOf(value)), 2)
    end
    local self_p = priv[self]
    if self_p.leftMargin then
        error("Cannot modify the raw margin of an Element with a dynamic margin", 2)
    end
    operation(dmx, self, value - self_p.lm, 0)
    flushOperations()
end

function setters:tm(value)
    validateElement(self, "self", false)
    if type(value) ~= "number" then
        error(("Invalid value: number expected, got %s"):format(floof.typeOf(value)), 2)
    end
    local self_p = priv[self]
    if self_p.topMargin then
        error("Cannot modify the raw margin of an Element with a dynamic margin", 2)
    end
    operation(dmy, self, value - self_p.tm, 0)
    flushOperations()
end

function setters:rm(value)
    validateElement(self, "self", false)
    if type(value) ~= "number" then
        error(("Invalid value: number expected, got %s"):format(floof.typeOf(value)), 2)
    end
    local self_p = priv[self]
    if self_p.rightMargin then
        error("Cannot modify the raw margin of an Element with a dynamic margin", 2)
    end
    operation(dmx, self, 0, value - self_p.rm)
    flushOperations()
end

function setters:bm(value)
    validateElement(self, "self", false)
    if type(value) ~= "number" then
        error(("Invalid value: number expected, got %s"):format(floof.typeOf(value)), 2)
    end
    local self_p = priv[self]
    if self_p.bottomMargin then
        error("Cannot modify the raw margin of an Element with a dynamic margin", 2)
    end
    operation(dmy, self, 0, value - self_p.bm)
    flushOperations()
end

function setters:xm(value)
    validateElement(self, "self", false)
    if type(value) ~= "number" then
        error(("Invalid value: number expected, got %s"):format(floof.typeOf(value)), 2)
    end
    local self_p = priv[self]
    if self_p.leftMargin or self_p.rightMargin then
        error("Cannot modify the raw margin of an Element with a dynamic margin", 2)
    end
    operation(dmx, self, value - self_p.lm, value - self_p.rm)
    flushOperations()
end

function setters:ym(value)
    validateElement(self, "self", false)
    if type(value) ~= "number" then
        error(("Invalid value: number expected, got %s"):format(floof.typeOf(value)), 2)
    end
    local self_p = priv[self]
    if self_p.topMargin or self_p.bottomMargin then
        error("Cannot modify the raw margin of an Element with a dynamic margin", 2)
    end
    operation(dmy, self, value - self_p.tm, value - self_p.bm)
    flushOperations()
end

function setters:m(value)
    validateElement(self, "self", false)
    if type(value) ~= "number" then
        error(("Invalid value: number expected, got %s"):format(floof.typeOf(value)), 2)
    end
    local self_p = priv[self]
    if self_p.leftMargin or self_p.topMargin or self_p.rightMargin or self_p.bottomMargin then
        error("Cannot modify the raw margin of an Element with a dynamic margin", 2)
    else
        operation(dmx, self, value - self_p.lm, value - self_p.rm)
        operation(dmy, self, value - self_p.tm, value - self_p.bm)
        flushOperations()
    end
end

function setters:lp(value)
    validateElement(self, "self", true)
    if type(value) ~= "number" then
        error(("Invalid value: number expected, got %s"):format(floof.typeOf(value)), 2)
    end
    local self_p = priv[self]
    if self_p.leftPadding then
        error("Cannot modify the raw padding of an Element with dynamic padding", 2)
    end
    operation(dpx, self, value - self_p.lp, 0)
    flushOperations()
end

function setters:tp(value)
    validateElement(self, "self", true)
    if type(value) ~= "number" then
        error(("Invalid value: number expected, got %s"):format(floof.typeOf(value)), 2)
    end
    local self_p = priv[self]
    if self_p.topPadding then
        error("Cannot modify the raw padding of an Element with dynamic padding", 2)
    end
    operation(dpy, self, value - self_p.tp, 0)
    flushOperations()
end

function setters:rp(value)
    validateElement(self, "self", true)
    if type(value) ~= "number" then
        error(("Invalid value: number expected, got %s"):format(floof.typeOf(value)), 2)
    end
    local self_p = priv[self]
    if self_p.rightPadding then
        error("Cannot modify the raw padding of an Element with dynamic padding", 2)
    end
    operation(dpx, self, 0, value - self_p.rp)
    flushOperations()
end

function setters:bp(value)
    validateElement(self, "self", true)
    if type(value) ~= "number" then
        error(("Invalid value: number expected, got %s"):format(floof.typeOf(value)), 2)
    end
    local self_p = priv[self]
    if self_p.bottomPadding then
        error("Cannot modify the raw padding of an Element with dynamic padding", 2)
    end
    operation(dpy, self, 0, value - self_p.bp)
    flushOperations()
end

function setters:xp(value)
    validateElement(self, "self", true)
    if type(value) ~= "number" then
        error(("Invalid value: number expected, got %s"):format(floof.typeOf(value)), 2)
    end
    local self_p = priv[self]
    if self_p.leftPadding or self_p.rightPadding then
        error("Cannot modify the raw padding of an Element with dynamic padding", 2)
    end
    operation(dpx, self, value - self_p.lp, value - self_p.rp)
    flushOperations()
end

function setters:yp(value)
    validateElement(self, "self", true)
    if type(value) ~= "number" then
        error(("Invalid value: number expected, got %s"):format(floof.typeOf(value)), 2)
    end
    local self_p = priv[self]
    if self_p.topPadding or self_p.bottomPadding then
        error("Cannot modify the raw padding of an Element with dynamic padding", 2)
    end
    operation(dpy, self, value - self_p.tp, value - self_p.bp)
    flushOperations()
end

function setters:p(value)
    validateElement(self, "self", true)
    if type(value) ~= "number" then
        error(("Invalid value: number expected, got %s"):format(floof.typeOf(value)), 2)
    end
    local self_p = priv[self]
    if self_p.leftPadding or self_p.topPadding or self_p.rightPadding or self_p.bottomPadding then
        error("Cannot modify the raw padding of an Element with dynamic padding", 2)
    else
        operation(dmx, self, value - self_p.lp, value - self_p.rp)
        operation(dmy, self, value - self_p.tp, value - self_p.bp)
        flushOperations()
    end
end

function setters:space(value)
    validateElement(self, "self", true)
    if type(value) ~= "number" then
        error(("Invalid value: number expected, got %s"):format(floof.typeOf(value)), 2)
    end
    local self_p = priv[self]
    if self_p.leftPadding or self_p.topPadding or self_p.rightPadding or self_p.bottomPadding then
        error("Cannot modify the raw padding of an Element with dynamic padding", 2)
    else
        operation(ds, self, value - self_p.space)
        flushOperations()
    end
end

function setters:offsetX(value)
    validateElement(self, "self", false)
    if type(value) ~= "number" then
        error(("Invalid value: number expected, got %s"):format(floof.typeOf(value)), 2)
    end
    local self_p = priv[self]
    operation(dx, self, value - self_p.offsetX, true)
    flushOperations()
end

function setters:offsetY(value)
    validateElement(self, "self", false)
    if type(value) ~= "number" then
        error(("Invalid value: number expected, got %s"):format(floof.typeOf(value)), 2)
    end
    local self_p = priv[self]
    operation(dy, self, value - self_p.offsetY, true)
    flushOperations()
end

function setters:lockedX(value)
    validateElement(self, "self", false)
    if type(value) ~= "boolean" then
        error(("Invalid value: boolean expected, got %s"):format(floof.typeOf(value)), 2)
    end
    priv[self].lockedX = value
end

function setters:lockedY(value)
    validateElement(self, "self", false)
    if type(value) ~= "boolean" then
        error(("Invalid value: boolean expected, got %s"):format(floof.typeOf(value)), 2)
    end
    priv[self].lockedY = value
end

function setters:locked(value)
    validateElement(self, "self", false)
    if type(value) ~= "boolean" then
        error(("Invalid value: boolean expected, got %s"):format(floof.typeOf(value)), 2)
    end
    priv[self].lockedX, priv[self].lockedY = value, value
end

function setters:width(value)
    validateElement(self, "self", false)
    local self_p = priv[self]
    if value == nil then
        self_p.width = nil
        return
    elseif type(value) == "string" then
        local val = tonumber(value:match("^%s*(%d*%.?%d+)%s*%%?%s*$"))
        if val then
            val = val / 100
            local parent_p = priv[self_p.parentElement] or Element_p
            self_p.width = val
            operation(dw, self, (parent_p.w - parent_p.lp - parent_p.rp) * val - self_p.w)
            flushOperations()
        else
            error(("Invalid value string (%q): must be a valid number or percentage"):format(value), 2)
        end
    elseif type(value) ~= "number" then
        error(("Invalid value: number or string expected, got %s"):format(floof.typeOf(value)), 2)
    end
end

function setters:height(value)
    validateElement(self, "self", false)
    local self_p = priv[self]
    if value == nil then
        self_p.height = nil
        return
    elseif type(value) == "string" then
        local val = tonumber(value:match("^%s*(%d*%.?%d+)%s*%%?%s*$"))
        if val then
            val = val / 100
            local parent_p = priv[self_p.parentElement] or Element_p
            self_p.height = val
            operation(dh, self, (parent_p.h - parent_p.tp - parent_p.bp) * val - self_p.h)
            flushOperations()
        else
            error(("Invalid value string (%q): must be a valid number or percentage"):format(value), 2)
        end
    elseif type(value) ~= "number" then
        error(("Invalid value: number or string expected, got %s"):format(floof.typeOf(value)), 2)
    end
end

function setters:leftMargin(value)
    validateElement(self, "self", false)
    local self_p = priv[self]
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
        error(("Invalid value: number expected, got %s"):format(floof.typeOf(value)), 2)
    end
    self_p.leftMargin = value
    local d = self_p.w * value - self_p.lm
    if self_p.anchorX == "stretch" then
        self_p.lm = self_p.lm + d
        operation(dx, self, d/2)
        operation(dw, self, -d)
    else
        operation(dmx, self, d, 0)
    end
    flushOperations()
end

function setters:topMargin(value)
    validateElement(self, "self", false)
    local self_p = priv[self]
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
        error(("Invalid value: number expected, got %s"):format(floof.typeOf(value)), 2)
    end
    self_p.topMargin = value
    local d = self_p.h * value - self_p.tm
    if self_p.anchorY == "stretch" then
        self_p.tm = self_p.tm + d
        operation(dy, self, d/2)
        operation(dh, self, -d)
    else
        operation(dmy, self, d, 0)
    end
    flushOperations()
end

function setters:rightMargin(value)
    validateElement(self, "self", false)
    local self_p = priv[self]
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
        error(("Invalid value: number expected, got %s"):format(floof.typeOf(value)), 2)
    end
    self_p.rightMargin = value
    local d = self_p.w * value - self_p.rm
    if self_p.anchorX == "stretch" then
        self_p.rm = self_p.rm + d
        operation(dx, self, -d/2)
        operation(dw, self, -d)
    else
        operation(dmx, self, 0, d)
    end
    flushOperations()
end

function setters:bottomMargin(value)
    validateElement(self, "self", false)
    local self_p = priv[self]
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
        error(("Invalid value: number expected, got %s"):format(floof.typeOf(value)), 2)
    end
    self_p.bottomMargin = value
    local d = self_p.h * value - self_p.bm
    if self_p.anchorY == "stretch" then
        self_p.bm = self_p.bm + d
        operation(dy, self, -d/2)
        operation(dh, self, -d)
    else
        operation(dmy, self, 0, d)
    end
    flushOperations()
end

function setters:horizontalMargin(value)
    validateElement(self, "self", false)
    local self_p = priv[self]
    if value == nil then
        self_p.leftMargin, self_p.rightMargin = nil, nil
        return
    elseif type(value) == "string" then
        local val = tonumber(value:match("^%s*(%d*%.?%d+)%s*%%?%s*$"))
        if val then
            value = val / 100
        else
            error(("Invalid value string (%q): must be a valid number or percentage"):format(value), 2)
        end
    elseif type(value) ~= "number" then
        error(("Invalid value: number expected, got %s"):format(floof.typeOf(value)), 2)
    end
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

function setters:verticalMargin(value)
    validateElement(self, "self", false)
    local self_p = priv[self]
    if value == nil then
        self_p.topMargin, self_p.bottomMargin = nil, nil
        return
    elseif type(value) == "string" then
        local val = tonumber(value:match("^%s*(%d*%.?%d+)%s*%%?%s*$"))
        if val then
            value = val / 100
        else
            error(("Invalid value string (%q): must be a valid number or percentage"):format(value), 2)
        end
    elseif type(value) ~= "number" then
        error(("Invalid value: number expected, got %s"):format(floof.typeOf(value)), 2)
    end
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
    validateElement(self, "self", false)
    local self_p = priv[self]
    if value == nil then
        self_p.leftMargin, self_p.topMargin, self_p.rightMargin, self_p.bottomMargin = nil, nil, nil, nil
        return
    elseif type(value) == "string" then
        local val = tonumber(value:match("^%s*(%d*%.?%d+)%s*%%?%s*$"))
        if val then
            value = val / 100
        else
            error(("Invalid value string (%q): must be a valid number or percentage"):format(value), 2)
        end
    elseif type(value) ~= "number" then
        error(("Invalid value: number expected, got %s"):format(floof.typeOf(value)), 2)
    end
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
    validateElement(self, "self", true)
    local self_p = priv[self]
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
        error(("Invalid value: number expected, got %s"):format(floof.typeOf(value)), 2)
    end
    self_p.leftPadding = value
    operation(dpx, self, self_p.w * value - self_p.lp, 0)
    flushOperations()
end

function setters:topPadding(value)
    validateElement(self, "self", true)
    local self_p = priv[self]
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
        error(("Invalid value: number expected, got %s"):format(floof.typeOf(value)), 2)
    end
    self_p.topPadding = value
    operation(dpy, self, self_p.h * value - self_p.tp, 0)
    flushOperations()
end

function setters:rightPadding(value)
    validateElement(self, "self", true)
    local self_p = priv[self]
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
        error(("Invalid value: number expected, got %s"):format(floof.typeOf(value)), 2)
    end
    self_p.rightPadding = value
    operation(dpx, self, 0, self_p.w * value - self_p.rp)
    flushOperations()
end

function setters:bottomPadding(value)
    validateElement(self, "self", true)
    local self_p = priv[self]
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
        error(("Invalid value: number expected, got %s"):format(floof.typeOf(value)), 2)
    end
    self_p.bottomPadding = value
    operation(dpy, self, 0, self_p.h * value - self_p.bp)
    flushOperations()
end

function setters:horizontalPadding(value)
    validateElement(self, "self", true)
    local self_p = priv[self]
    if value == nil then
        self_p.leftPadding, self_p.rightPadding = nil, nil
        return
    elseif type(value) == "string" then
        local val = tonumber(value:match("^%s*(%d*%.?%d+)%s*%%?%s*$"))
        if val then
            value = val / 100
        else
            error(("Invalid value string (%q): must be a valid number or percentage"):format(value), 2)
        end
    elseif type(value) ~= "number" then
        error(("Invalid value: number expected, got %s"):format(floof.typeOf(value)), 2)
    end
    self_p.leftPadding, self_p.rightPadding = value, value
    operation(dpx, self, self_p.w * value - self_p.lp, self_p.w * value - self_p.rp)
    flushOperations()
end

function setters:verticalPadding(value)
    validateElement(self, "self", true)
    local self_p = priv[self]
    if value == nil then
        self_p.topPadding, self_p.bottomPadding = nil, nil
        return
    elseif type(value) == "string" then
        local val = tonumber(value:match("^%s*(%d*%.?%d+)%s*%%?%s*$"))
        if val then
            value = val / 100
        else
            error(("Invalid value string (%q): must be a valid number or percentage"):format(value), 2)
        end
    elseif type(value) ~= "number" then
        error(("Invalid value: number expected, got %s"):format(floof.typeOf(value)), 2)
    end
    self_p.topPadding, self_p.bottomPadding = value, value
    operation(dpy, self, self_p.h * value - self_p.tp, self_p.h * value - self_p.bp)
    flushOperations()
end

function setters:padding(value)
    validateElement(self, "self", true)
    local self_p = priv[self]
    if value == nil then
        self_p.leftPadding, self_p.topPadding, self_p.rightPadding, self_p.bottomPadding = nil, nil, nil, nil
        return
    elseif type(value) == "string" then
        local val = tonumber(value:match("^%s*(%d*%.?%d+)%s*%%?%s*$"))
        if val then
            value = val / 100
        else
            error(("Invalid value string (%q): must be a valid number or percentage"):format(value), 2)
        end
    elseif type(value) ~= "number" then
        error(("Invalid value: number expected, got %s"):format(floof.typeOf(value)), 2)
    end
    self_p.leftPadding, self_p.topPadding, self_p.rightPadding, self_p.bottomPadding = value, value, value, value
    local l, t, r, b = self_p.w * value - self_p.lp, self_p.h * value - self_p.tp, self_p.w * value - self_p.rp, self_p.h * value - self_p.bp
    operation(dpx, self, l, r)
    operation(dpy, self, t, b)
    flushOperations()
end

function setters:spacing(value)
    validateElement(self, "self", true)
    local self_p = priv[self]
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
        error(("Invalid value: number expected, got %s"):format(floof.typeOf(value)), 2)
    end
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

function setters:alignX(value)
    validateElement(self, "self", false)
    local self_p = priv[self]
    if value ~= nil and value ~= "left" and value ~= "center" and value ~= "right" and value ~= "stretch" then
        error(("Invalid value (%s), must be one of: left, center, right, stretch"):format(value), 2)
    end
    local previous = self_p.anchorX
    self_p.alignX = value
    local parent_p = priv[self_p.parentElement] or Element_p
    value = value or (self_p.inLayout and parent_p.layoutDirection == "column" and parent_p.alignChildren) or "center"
    if value == previous or self_p.inLayout and parent_p.layoutDirection == "row" then return end
    self_p.anchorX = value
    local d, room = 0, parent_p.w - parent_p.lp - parent_p.rp - self_p.w - self_p.lm - self_p.rm
    if previous == "left" then
        d = d + room/2
    elseif previous == "right" then
        d = d - room/2
    end
    if value == "left" then
        d = d - room/2
    elseif value == "right" then
        d = d + room/2
    elseif value == "stretch" then
        d = d + self_p.lm/2 - self_p.rm/2
    end
    operation(dx, self, d)
    if value == "stretch" then operation(dw, self, room) end
    flushOperations()
end

function setters:alignY(value)
    validateElement(self, "self", false)
    local self_p = priv[self]
    if value ~= nil and value ~= "top" and value ~= "middle" and value ~= "bottom" and value ~= "expand" then
        error(("Invalid value (%s), must be one of: top, middle, bottom, expand"):format(value), 2)
    end
    local previous = self_p.anchorY
    self_p.alignY = value
    local parent_p = priv[self_p.parentElement] or Element_p
    value = value or (self_p.inLayout and parent_p.layoutDirection == "row" and parent_p.alignChildren) or "middle"
    if value == previous or self_p.inLayout and parent_p.layoutDirection == "column" then return end
    self_p.anchorY = value
    local d, room = 0, parent_p.h - parent_p.tp - parent_p.bp - self_p.h - self_p.tm - self_p.bm
    if previous == "top" then
        d = d + room/2
    elseif previous == "bottom" then
        d = d - room/2
    end
    if value == "top" then
        d = d - room/2
    elseif value == "bottom" then
        d = d + room/2
    elseif value == "expand" then
        d = d + self_p.tm/2 - self_p.bm/2
    end
    operation(dy, self, d)
    if value == "expand" then operation(dh, self, room) end
    flushOperations()
end

function setters:align(value)
    validateElement(self, "self", false)
    local self_p = priv[self]
    local x, y
    if value ~= nil then
        if type(value) == "string" then
            local a, b = value:match("^(.-)%-(.-)$")
            if a and b then
                if a == "top"  or a == "middle" or a == "bottom" or a == "expand" or
                   b == "left" or b == "center" or b == "right"  or b == "stretch"
                then x, y = b, a else x, y = a, b end
            elseif value == "left" or value == "center" or value == "right"  or value == "stretch" then
                x = value
            elseif value == "top"  or value == "middle" or value == "bottom" or value == "expand" then
                y = value
            else
                error(("Invalid value (%s), must be one of: left, center, right, stretch, top, middle, bottom, expand or a hyphen-separated pair of these values"):format(value), 2)
            end
        else
            error(("Invalid value: string expected, got %s"):format(value), 2)
        end
    end
    if x ~= nil and x ~= "left" and x ~= "center" and x ~= "right" and x ~= "stretch" then
        error(("Invalid X value (%s), must be one of: left, center, right, stretch"):format(x), 2)
    end
    if y ~= nil and y ~= "top" and y ~= "middle" and y ~= "bottom" and y ~= "expand" then
        error(("Invalid Y value (%s), must be one of: top, middle, bottom, expand"):format(y), 2)
    end
    local px, py = self_p.anchorX, self_p.anchorY
    self_p.alignX, self_p.alignY = x, y
    local parent_p = priv[self_p.parentElement] or Element_p
    x = x or (self_p.inLayout and parent_p.layoutDirection == "column" and parent_p.alignChildren) or "center"
    y = y or (self_p.inLayout and parent_p.layoutDirection == "row"    and parent_p.alignChildren) or "middle"
    if x ~= px and (not self_p.inLayout or parent_p.layoutDirection ~= "row") then
        self_p.anchorX = x
        local d, room = 0, parent_p.w - parent_p.lp - parent_p.rp - self_p.w - self_p.lm - self_p.rm
        if px == "left" then
            d = d + room/2
        elseif px == "right" then
            d = d - room/2
        end
        if x == "left" then
            d = d - room/2
        elseif x == "right" then
            d = d + room/2
        elseif x == "stretch" then
            d = d + self_p.lm/2 - self_p.rm/2
        end
        operation(dx, self, d)
        if x == "stretch" then operation(dw, self, room) end
    end
    if y ~= py and (not self_p.inLayout or parent_p.layoutDirection ~= "column") then
        self_p.anchorY = y
        local d, room = 0, parent_p.h - parent_p.tp - parent_p.bp - self_p.h - self_p.tm - self_p.bm
        if py == "top" then
            d = d + room/2
        elseif py == "bottom" then
            d = d - room/2
        end
        if y == "top" then
            d = d - room/2
        elseif y == "bottom" then
            d = d + room/2
        elseif y == "expand" then
            d = d + self_p.tm/2 - self_p.bm/2
        end
        operation(dy, self, d)
        if y == "expand" then operation(dh, self, room) end
    end
    flushOperations()
end

function setters:inLayout(value)
    validateElement(self, "self", false)
    if type(value) ~= "boolean" then
        error(("Invalid value: boolean expected, got %s"):format(floof.typeOf(value)), 2)
    end
    local self_p = priv[self]
    if self_p.inLayout == value then return end
    self_p.inLayout = value
    operation(anchor, self)
    if active[self] then (value and addToLayout or removeFromLayout)(self) end
    flushOperations()
end

function setters:layoutDirection(value)
    validateElement(self, "self", true)
    if value ~= "row" and value ~= "column" then
        error(("Invalid value (%s), must be one of: row, column"):format(value), 2)
    end
    local self_p = priv[self]
    if self_p.layoutDirection == value then return end
    self_p.layoutDirection = value
    if value == "row" then
        local room = self_p.w - self_p.lp - self_p.rp
        if self_p.justifyChildren == "top" then
            self_p.justifyChildren = "left"
        elseif self_p.justifyChildren == "middle" then
            self_p.justifyChildren = "center"
        elseif self_p.justifyChildren == "bottom" then
            self_p.justifyChildren = "right"
        end
        if self_p.alignChildren == "left" then
            self_p.alignChildren = "top"
        elseif self_p.alignChildren == "center" then
            self_p.alignChildren = "middle"
        elseif self_p.alignChildren == "right" then
            self_p.alignChildren = "bottom"
        end
        for elem in iterateElementChildren(self) do
            local elem_p = priv[elem]
            if elem_p.inLayout then
                if elem_p.layoutIndex then
                    room = room - elem_p.w - elem_p.lm - elem_p.rm
                end
                operation(anchor, elem, true)
            end
        end
        operation(droom, self, room - self_p.extraRoom)
    elseif value == "column" then
        local room = self_p.h - self_p.tp - self_p.bp
        if self_p.justifyChildren == "left" then
            self_p.justifyChildren = "top"
        elseif self_p.justifyChildren == "center" then
            self_p.justifyChildren = "middle"
        elseif self_p.justifyChildren == "right" then
            self_p.justifyChildren = "bottom"
        end
        if self_p.alignChildren == "top" then
            self_p.alignChildren = "left"
        elseif self_p.alignChildren == "middle" then
            self_p.alignChildren = "center"
        elseif self_p.alignChildren == "bottom" then
            self_p.alignChildren = "right"
        end
        for elem in iterateElementChildren(self) do
            local elem_p = priv[elem]
            if elem_p.inLayout then
                if elem_p.layoutIndex then
                    room = room - elem_p.h - elem_p.tm - elem_p.bm
                end
                operation(anchor, elem, true)
            end
        end
        operation(droom, self, room - self_p.extraRoom)
    end
    flushOperations()
end

function setters:justifyChildren(value)
    validateElement(self, "self", true)
    local self_p = priv[self]
    if self_p.layoutDirection == "row" and value ~= "left" and value ~= "center" and value ~= "right" then
        error(("Invalid value (%s), must be one of: left, center, right"):format(value), 2)
    elseif self_p.layoutDirection == "column" and value ~= "top" and value ~= "middle" and value ~= "bottom" then
        error(("Invalid value (%s), must be one of: top, middle, bottom"):format(value), 2)
    end
    if self_p.justifyChildren == value then return end
    local d = 0
    if self_p.justifyChildren == "left" or self_p.justifyChildren == "top" then
        d = d + self_p.extraRoom/2
    elseif self_p.justifyChildren == "center" or self_p.justifyChildren == "middle" then
        d = d
    elseif self_p.justifyChildren == "right" or self_p.justifyChildren == "bottom" then
        d = d - self_p.extraRoom/2
    end
    self_p.justifyChildren = value
    if value == "left" or value == "top" then
        d = d - self_p.extraRoom/2
        self_p.minScroll, self_p.maxScroll = math.min(self_p.extraRoom, 0), 0
    elseif value == "center" or value == "middle" then
        self_p.minScroll, self_p.maxScroll = math.min(self_p.extraRoom/2, 0), math.max(-self_p.extraRoom/2, 0)
    elseif value == "right" or value == "bottom" then
        d = d + self_p.extraRoom/2
        self_p.minScroll, self_p.maxScroll = 0, math.max(-self_p.extraRoom, 0)
    end
    if self_p.scroll < self_p.minScroll then
        d = d + self_p.minScroll - self_p.scroll
        self_p.scroll = self_p.minScroll
    elseif self_p.scroll > self_p.maxScroll then
        d = d + self_p.maxScroll - self_p.scroll
        self_p.scroll = self_p.maxScroll
    end
    for elem in iterateElementChildren(self) do
        local elem_p = priv[elem]
        if elem_p.inLayout then
            if self_p.layoutDirection == "row" then
                elem_p.anchorX = value
                operation(dx, elem, d)
            elseif self_p.layoutDirection == "column" then
                elem_p.anchorY = value
                operation(dy, elem, d)
            end
        end
    end
end

function setters:alignChildren(value)
    validateElement(self, "self", true)
    local self_p = priv[self]
    if self_p.layoutDirection == "row" and value ~= "top" and value ~= "middle" and value ~= "bottom" and value ~= "expand" then
        error(("Invalid value (%s), must be one of: top, middle, bottom, expand"):format(value), 2)
    elseif self_p.layoutDirection == "column" and value ~= "left" and value ~= "center" and value ~= "right" and value ~= "stretch" then
        error(("Invalid value (%s), must be one of: left, center, right, stretch"):format(value), 2)
    end
    if self_p.alignChildren == value then return end
    local previous = self_p.alignChildren
    self_p.alignChildren = value
    for elem in iterateElementChildren(self) do
        local elem_p = priv[elem]
        if elem_p.inLayout then
            if self_p.layoutDirection == "row" and not elem_p.alignY then
                elem_p.anchorY = value
                local d, room = 0, self_p.h - self_p.tp - self_p.bp - elem_p.h - elem_p.tm - elem_p.bm
                if previous == "top" then
                    d = d + room/2
                elseif previous == "bottom" then
                    d = d - room/2
                end
                if value == "top" then
                    d = d - room/2
                elseif value == "bottom" then
                    d = d + room/2
                elseif value == "expand" then
                    d = d + elem_p.tm/2 - elem_p.bm/2
                end
                operation(dy, elem, d)
                if value == "expand" then operation(dh, elem, room) end
            elseif self_p.layoutDirection == "column" and not elem_p.alignX then
                elem_p.anchorX = value
                local d, room = 0, self_p.w - self_p.lp - self_p.rp - elem_p.w - elem_p.lm - elem_p.rm
                if previous == "left" then
                    d = d + room/2
                elseif previous == "right" then
                    d = d - room/2
                end
                if value == "left" then
                    d = d - room/2
                elseif value == "right" then
                    d = d + room/2
                elseif value == "stretch" then
                    d = d + elem_p.lm/2 - elem_p.rm/2
                end
                operation(dx, elem, d)
                if value == "stretch" then operation(dw, elem, room) end
            end
        end
    end
end

function setters:spaceAround(value)
    validateElement(self, "self", true)
    if type(value) ~= "boolean" then
        error(("Invalid value: boolean expected, got %s"):format(floof.typeOf(value)), 2)
    end
    local self_p = priv[self]
    if self_p.spaceAround == value then return end
    self_p.spaceAround = value
    if self_p.layoutCount > 0 then
        local sign = value and 1 or -1
        local d = 0
        if self_p.justifyChildren == "left" or self_p.justifyChildren == "top" then
            d =  sign * self_p.totalSpace
        elseif self_p.justifyChildren == "right" or self_p.justifyChildren == "bottom" then
            d = -sign * self_p.totalSpace
        end
        for elem in iterateElementChildren(self) do
            if priv[elem].inLayout then
                if self_p.layoutDirection == "row" then
                    operation(dx, elem, d)
                elseif self_p.layoutDirection == "column" then
                    operation(dy, elem, d)
                end
            end
        end
        operation(droom, self, 2 * -sign * self_p.totalSpace)
    else
        self_p.totalSpace = self_p.totalSpace + (value and 1 or -1) * self_p.extraRoom
    end
    flushOperations()
end

function setters:expandSpace(value)
    validateElement(self, "self", true)
    if type(value) ~= "boolean" then
        error(("Invalid value: boolean expected, got %s"):format(floof.typeOf(value)), 2)
    end
    local self_p = priv[self]
    if self_p.expandSpace == value then return end
    self_p.expandSpace = value
    local ns = math.max(self_p.layoutCount + (self_p.spaceAround and 1 or -1), 0)
    if ns > 0 then
        if value then
            local d = math.max(self_p.extraRoom, 0) / ns
            if d > 0 then operation(ds, self, d, true) end
        else
            local d = self_p.space - self_p.totalSpace
            if d < 0 then operation(ds, self, d, true) end
        end
    end
    flushOperations()
end

function setters:scroll(value)
    validateElement(self, "self", true)
    if type(value) ~= "number" then
        error(("Invalid value: number expected, got %s"):format(floof.typeOf(value)), 2)
    end
    local self_p = priv[self]
    value = math.max(self_p.minScroll, math.min*self_p.maxScroll, value)
    local d = value - self_p.scroll
    self_p.scroll = value
    for elem in iterateElementChildren(self) do
        local elem_p = priv[elem]
        if elem_p.inLayout then
            if self_p.layoutDirection == "row" then
                operation(dx, elem, d)
            elseif self_p.layoutDirection == "column" then
                operation(dy, elem, d)
            end
        end
    end
    flushOperations()
end

-- sorting order

function isBefore(self, other)
    validateElement(self, "self")
    validateElement(other, "value")
    local self_p, other_p = priv[self], priv[other]
    if self_p.parentElement ~= other_p.parentElement then
        error("Invalid value: must be an Element sibling of the object", 2)
    end
    return before[self][other] or false
end
Element.isBefore = isBefore

function setSortOrder(self, priority)
    validateElement(self, "self")
    if type(priority) ~= "number" then
        error(("Invalid value: number expected, got %s"):format(floof.typeOf(priority)), 2)
    end
    local self_p = priv[self]
    self_p.sortingPriority = priority
    local parent_p = priv[self_p.parentElement] or Element_p
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
                    operation(move, sib, -self_p[size] - self_p[m1] - self_p[m2] - parent_p.totalSpace)
                end
                if sib_p.layoutIndex then
                    moveself = moveself + sib_p[size] + sib_p[m1] + sib_p[m2] + parent_p.totalSpace
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
                    operation(move, sib, self_p[size] + self_p[m1] + self_p[m2] + parent_p.totalSpace)
                end
                if sib_p.layoutIndex then
                    moveself = moveself - sib_p[size] - sib_p[m1] - sib_p[m2] - parent_p.totalSpace
                end
                if self_p.layoutIndex and sib_p.layoutIndex then
                    self_p.layoutIndex = self_p.layoutIndex - 1
                    sib_p.layoutIndex = sib_p.layoutIndex + 1
                end
            end
        end
    end
    operation(move, self, moveself)
    flushOperations()
    if initialized[self] then
        floof.safeInvoke(Object.invokeHandlers, self, "reordered")
        handleCallback(self, "reordered")
    end
end
Element.setSortOrder, setters.sortingPriority = setSortOrder, setSortOrder

function moveBefore(self, nxt)
    validateElement(self, "self")
    if nxt ~= nil then validateElement(nxt, "value") end
    if self == nxt then error("Invalid value: equal to self", 2) end
    local self_p, nxt_p = priv[self], priv[nxt]
    if nxt and nxt_p.parentElement ~= self_p.parentElement then
        error("Invalid value: must be an Element sibling of the object", 2)
    end
    if self_p.nextElement == nxt then return end
    local parent_p = priv[self_p.parentElement] or Element_p
    local pos  = parent_p.layoutDirection == "row" and "x"  or "y"
    local size = parent_p.layoutDirection == "row" and "w"  or "h"
    local m1   = parent_p.layoutDirection == "row" and "lm" or "tm"
    local m2   = parent_p.layoutDirection == "row" and "rm" or "bm"
    local move = parent_p.layoutDirection == "row" and  dx  or  dy
    local moveself = 0
    if not nxt or before[self][nxt] then
        for sib in iterateElement(self) do
            local sib_p = priv[sib]
            if sib == nxt then break end
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
                    operation(move, sib, -self_p[size] - self_p[m1] - self_p[m2] - parent_p.totalSpace)
                end
                if sib_p.layoutIndex then
                    moveself = moveself + sib_p[size] + sib_p[m1] + sib_p[m2] + parent_p.totalSpace
                end
                if self_p.layoutIndex and sib_p.layoutIndex then
                    self_p.layoutIndex = self_p.layoutIndex + 1
                    sib_p.layoutIndex = sib_p.layoutIndex - 1
                end
            end
        end
    else
        for sib in backtrackElement(self) do
            local sib_p = priv[sib]
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
                    operation(move, sib, self_p[size] + self_p[m1] + self_p[m2] + parent_p.totalSpace)
                end
                if sib_p.layoutIndex then
                    moveself = moveself - sib_p[size] - sib_p[m1] - sib_p[m2] - parent_p.totalSpace
                end
                if self_p.layoutIndex and sib_p.layoutIndex then
                    self_p.layoutIndex = self_p.layoutIndex - 1
                    sib_p.layoutIndex = sib_p.layoutIndex + 1
                end
            end
            if sib == nxt then break end
        end
    end
    operation(move, self, moveself)
    flushOperations()
    if initialized[self] then
        floof.safeInvoke(Object.invokeHandlers, self, "reordered")
        handleCallback(self, "reordered")
    end
end
Element.moveBefore, setters.nextElement = moveBefore, moveBefore

function moveAfter(self, prv)
    validateElement(self, "self")
    if prv ~= nil then validateElement(prv, "value") end
    if self == prv then error("Invalid value: equal to self", 2) end
    local self_p, prv_p = priv[self], priv[prv]
    if prv and prv_p.parentElement ~= self_p.parentElement then
        error("Invalid value: must be an Element sibling of the object", 2)
    end
    if self_p.previousElement == prv then return end
    local parent_p = priv[self_p.parentElement] or Element_p
    local pos  = parent_p.layoutDirection == "row" and "x"  or "y"
    local size = parent_p.layoutDirection == "row" and "w"  or "h"
    local m1   = parent_p.layoutDirection == "row" and "lm" or "tm"
    local m2   = parent_p.layoutDirection == "row" and "rm" or "bm"
    local move = parent_p.layoutDirection == "row" and  dx  or  dy
    local moveself = 0
    if before[self][prv] then
        for sib in iterateElement(self) do
            local sib_p = priv[sib]
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
                    operation(move, sib, -self_p[size] - self_p[m1] - self_p[m2] - parent_p.totalSpace)
                end
                if sib_p.layoutIndex then
                    moveself = moveself + sib_p[size] + sib_p[m1] + sib_p[m2] + parent_p.totalSpace
                end
                if self_p.layoutIndex and sib_p.layoutIndex then
                    self_p.layoutIndex = self_p.layoutIndex + 1
                    sib_p.layoutIndex = sib_p.layoutIndex - 1
                end
            end
            if sib == prv then break end
        end
    else
        for sib in backtrackElement(self) do
            local sib_p = priv[sib]
            if sib == prv then break end
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
                    operation(move, sib, self_p[size] + self_p[m1] + self_p[m2] + parent_p.totalSpace)
                end
                if sib_p.layoutIndex then
                    moveself = moveself - sib_p[size] - sib_p[m1] - sib_p[m2] - parent_p.totalSpace
                end
                if self_p.layoutIndex and sib_p.layoutIndex then
                    self_p.layoutIndex = self_p.layoutIndex - 1
                    sib_p.layoutIndex = sib_p.layoutIndex + 1
                end
            end
        end
    end
    operation(move, self, moveself)
    flushOperations()
    if initialized[self] then
        floof.safeInvoke(Object.invokeHandlers, self, "reordered")
        handleCallback(self, "reordered")
    end
end
Element.moveAfter, setters.backward = moveAfter, moveAfter

function setFirstChild(self, first)
    validateElement(self, "self", true)
    validateElement(first, "value")
    local self_p, first_p = priv[self], priv[first]
    if first_p.parentElement ~= self then
        error("Invalid value: must be an Element child of the object", 2)
    end
    if self_p.firstChildElement == first then return end
    floof.safeInvoke(moveBefore, first, self_p.firstChildElement)
end
Element.setFirstChild, setters.firstChildElement = setFirstChild, setFirstChild

function setLastChild(self, last)
    validateElement(self, "self", true)
    validateElement(last, "value")
    local self_p, last_p = priv[self], priv[last]
    if last_p.parentElement ~= self then
        error("Invalid value: must be an Element child of the object", 2)
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