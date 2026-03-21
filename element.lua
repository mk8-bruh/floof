-- FLOOF: Fast Lua Element-Oriented Framework
-- Copyright (c) 2026 Matus Kordos

local PATH = (...):match("^(.+%.).-$") or ""
local floof = require(PATH)
local array, vec, Object = floof.array, floof.vector, floof.object

local Element = Object:class("Element")

-- function pre-defs

local dx, dy, dw, dh,
      setx, sety, setw, seth,
      cont

local setSortOrder,
      moveBefore, moveAfter,
      setFirstChild, setLastChild,
      iterElem, backIterElem,
      iterElemCh, backIterElemCh,
      previousActiveElem, nextActiveElem,
      firstActiveChElem, lastActiveChElem,
      hierPrevElem, hierNextElem,
      hierElem, backHierElem

-- private environment

local Element_p = {
    w = 0, h = 0,
    layoutDirection = "vertical",
    justifyChildren = "start", alignChildren = "center",
    paddingL = 0, paddingT = 0, paddingR = 0, paddingB = 0,
    paddingLeft = nil, paddingTop = nil, paddingRight = nil, paddingBottom = nil,
    contentWidth = 0, contentHeight = 0,
    spacing = 0, expandSpace = nil,
    firstChildElement = nil, lastChildElement = nil, childElementCount = 0
}
local priv = setmetatable({[Element] = Element_p}, {__mode = "k"})

local function initPrivInstance(self)
    local p = {
        isInitialized = false, firstActivated = false, isDeleted = false,
        parentElement = nil,
        previousElement = nil, nextElement = nil, sortingPriority = 0,
        x = 0, y = 0, w = 0, h = 0,
        width = nil, height = nil,
        alignSelfX = nil, alignSelfY = nil,
        marginL = 0, marginT = 0, marginR = 0, marginB = 0,
        marginLeft = nil, marginTop = nil, marginRight = nil, marginBottom = nil,
        inLayout = true,
        layoutDirection = "vertical",
        justifyChildren = "start", alignChildren = "center",
        paddingL = 0, paddingT = 0, paddingR = 0, paddingB = 0,
        paddingLeft = nil, paddingTop = nil, paddingRight = nil, paddingBottom = nil,
        contentWidth = 0, contentHeight = 0,
        spacing = 0, expandSpace = nil,
        firstChildElement = nil, lastChildElement = nil, childElementCount = 0,
    }
    priv[self] = p
    return p
end

-- helpers

local function validateElement(self, name)
    local typeStr = acceptClass and "Element instance or the class" or "Element instance"
    if not (acceptClass and self == Element) and
       not floof.instanceOf(self, Element)
    then
        error(("Invalid %s: %s expected, got %s"):format(name, typeStr, floof.typeOf(self)), 3)
    elseif not priv[self] then
        error(("Invalid %s: Element not properly constructed"):format(name), 3)
    elseif priv[self].isDeleted then
        error(("Invalid %s: deleted"):format(name), 3)
    end
end

local function handleCallback(self, func, ...)
    if not priv[self].isInitialized then return false
    elseif floof.isCallable(self[func]) then
        local s, e = pcall(self[func], self, ...)
        if not s then error(e, 3) else return e end
    else return self[func] end
end

local function privKeyIterator(k) return floof.newIterator(function(self) return priv[self] and priv[self][k] end) end

-- public interface

function Element:isConstructed() return priv[self] ~= nil end

local getters = {
    
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

-- sorting order

function setSortOrder(self, sortingPriority)
    validateElement(self, "caller")
    if type(sortingPriority) ~= "number" then
        error("Value must be a number", 2)
    end
    local self_p = priv[self]
    self_p.sortingPriority = sortingPriority
    local parent = self_p.parentElement or Element
    local parent_p = priv[parent]
    if self_p.nextElement and priv[self_p.nextElement].sortingPriority > sortingPriority then
        for sib in iterElem(self) do
            local sib_p = priv[sib]
            if sib_p.sortingPriority > sortingPriority then break end
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
        end
    elseif self_p.previousElement and priv[self_p.previousElement].sortingPriority <= sortingPriority then
        for sib in backIterElem(self) do
            local sib_p = priv[sib]
            if sib_p.sortingPriority <= sortingPriority then break end
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
        end
    end
    if self_p.isInitialized then
        invokeHandlers(self, "depthchanged")
        handleCallback(self, "depthchanged")
    end
end
Element.setSortOrder, setters.sortingPriority = setSortOrder, setSortOrder

function moveBefore(self, previousElement)
    validateElement(self, "caller")
    if previousElement ~= nil then validateElement(previousElement, "value") end
    if self == previousElement then error("Invalid value: equal to caller", 2) end
    local self_p, backward_p = priv[self], priv[previousElement]
    if previousElement and backward_p.parent ~= self_p.parent then
        error("Invalid value: object must be a sibling of the caller", 2)
    end
    if self_p.previousElement == previousElement then return end
    local parent_p = priv[self_p.parent] or Element_p
    local p_backward = self_p.previousElement
    local x, y = parent_p.pointerX, parent_p.pointerY
    if self_p.nextElement then
        priv[self_p.nextElement].previousElement = self_p.previousElement
    else
        parent_p.frontmost = self_p.previousElement
    end
    if self_p.previousElement then
        priv[self_p.previousElement].nextElement = self_p.nextElement
    else
        parent_p.backmost = self_p.nextElement
    end
    if previousElement then
        self_p.sortingPriority = backward_p.sortingPriority
        if backward_p.nextElement then
            priv[backward_p.nextElement].previousElement = self
        else
            parent_p.frontmost = self
        end
        backward_p.nextElement = self
    else
        self_p.sortingPriority = priv[parent_p.backmost].sortingPriority
        priv[parent_p.backmost].previousElement, parent_p.backmost = self, self
    end
    if self_p.isInitialized then
        invokeHandlers(self, "orderchanged")
        handleCallback(self, "orderchanged")
    end
end
Element.moveBefore, setters.previousElement = moveBefore, moveBefore

function moveAfter(self, nextElement)
    validateElement(self, "caller")
    if nextElement ~= nil then validateElement(nextElement, "value") end
    if self == nextElement then error("Invalid value: equal to caller", 2) end
    local self_p, forward_p = priv[self], priv[nextElement]
    if nextElement and forward_p.parent ~= self_p.parent then
        error("Invalid value: object must be a sibling of the caller", 2)
    end
    if self_p.nextElement == nextElement then return end
    local parent_p = priv[self_p.parent] or Element_p
    local p_backward = self_p.previousElement
    local x, y = parent_p.pointerX, parent_p.pointerY
    if self_p.nextElement then
        priv[self_p.nextElement].previousElement = self_p.previousElement
    else
        parent_p.frontmost = self_p.previousElement
    end
    if self_p.previousElement then
        priv[self_p.previousElement].nextElement = self_p.nextElement
    else
        parent_p.backmost = self_p.nextElement
    end
    if nextElement then
        self_p.sortingPriority = forward_p.sortingPriority
        if forward_p.previousElement then
            priv[forward_p.previousElement].nextElement = self
        else
            parent_p.backmost = self
        end
        forward_p.previousElement = self
    else
        self_p.sortingPriority = priv[parent_p.frontmost].sortingPriority
        priv[parent_p.frontmost].nextElement, parent_p.frontmost = self, self
    end
    if self_p.isHovered and forward_p.behindHover then
        for sib in backIterElem(p_backward, true) do
            if sib == self then break end
            local sib_p = priv[sib]
            sib_p.behindHover = false
            if floof.safeInvoke(checkHover, sib) then break end
        end
    elseif forward_p.isHovered or forward_p.behindHover then
        self_p.behindHover = true
    end
    if self_p.isInitialized then
        invokeHandlers(self, "depthchanged")
        handleCallback(self, "depthchanged")
    end
end
Element.moveAfter, setters.nextElement = moveAfter, moveAfter

function setFirstChild(self, frontmost)
    validateElement(self, "caller", true)
    validateElement(frontmost, "value")
    local self_p, frontmost_p = priv[self], priv[frontmost]
    if frontmost.parent ~= self then
        error("Invalid value: object must be a sibling of the caller", 2)
    end
    if self_p.frontmost == frontmost then return end
    floof.safeInvoke(moveBefore, frontmost, self_p.frontmost)
end
Element.moveToFront, setters.frontmost = setFirstChild, setFirstChild

function setLastChild(self, backmost)
    validateElement(self, "caller", true)
    validateElement(backmost, "value")
    local self_p, backmost_p = priv[self], priv[backmost]
    if bacmost_p.parent ~= self then
        error("Invalid value: object must be a sibling of the caller", 2)
    end
    if self_p.backmost == backmost then return end
    floof.safeInvoke(moveAfter, backmost, self_p.backmost)
end
Element.moveToBack, setters.backmost = setLastChild, setLastChild

function previousActiveElem(self)
    repeat
        self = priv[self].nextElement
    until not self or priv[self].isActive
    return self
end
function nextActiveElem(self)
    repeat
        self = priv[self].previousElement
    until not self or priv[self].isActive
    return self
end
getters.previousActiveElem, getters.nextActiveElem = previousActiveElem, nextActiveElem

function firstActiveChElem(self)
    local frontmost = priv[self].frontmost
    while frontmost and not priv[frontmost].isActive do
        frontmost = priv[frontmost].previousElement
    end
    return frontmost
end
function lastActiveChElem(self)
    local backmost = priv[self].backmost
    while backmost and not priv[backmost].isActive do
        backmost = priv[backmost].nextElement
    end
    return backmost
end
getters.firstActiveChElem, getters.lastActiveChElem = firstActiveChElem, lastActiveChElem

iterElem = privKeyIterator("nextElement")
function iterElemCh(self)
    if priv[self] then
        return iterElem(priv[self].backmost, true)
    else
        return rawget, {}
    end
end
Element.iterElem, Element.iterElemCh = iterElem, iterElemCh

backIterElem = privKeyIterator("previousElement")
function backIterElemCh(self)
    if priv[self] then
        return backIterElem(priv[self].frontmost, true)
    else
        return rawget, {}
    end
end
Element.backIterElem, Element.backIterElemCh = backIterElem, backIterElemCh

function hierPrevElem(self, start)
    if not priv[self] then return end
    if priv[self].backmost then return priv[self].backmost end
    for obj in ancestors(self) do
        if obj == start then return end
        if priv[obj].nextElement then return priv[obj].nextElement end
    end
end
hierElem = floof.newIterator(hierPrevElem)
Element.hierElem, Element.hierPrevElem = hierElem, hierPrevElem

function hierNextElem(self, start)
    if not priv[self] then return end
    if priv[self].frontmost then return priv[self].frontmost end
    for obj in ancestors(self) do
        if obj == start then return end
        if priv[obj].previousElement then return priv[obj].previousElement end
    end
end
backHierElem = floof.newIterator(hierNextElem)
Element.backHierElem, Element.hierNextElem = backHierElem, hierNextElem

-- logic

function dx(self, dx)

end

-- event hooks

Element:registerHandler("constructed", function(self)
    local self_p = initPrivInstance(self)
end)

Element:registerHandler("initialized", function(self)
    local self_p = priv[self]
    self_p.isInitialized = true
end)

Element:registerHandler("deleted", function(self)
    local self_p = priv[self]
    self_p.isDeleted = true
end)

Element:registerHandler("orphaned", function(self)

end)
Element:registerHandler("addedto", function(self, parent)

end)

Element:registerHandler("activated", function(self)

end)
Element:registerHandler("deactivated", function(self)

end)

return Element