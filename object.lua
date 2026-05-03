local WARN_QUIT_BLOCK = true
local QUIT_BLOCK_MESSAGE = [[\x1b[1;33m!! Quitting was blocked by <%s>\x1b[22m
!! Please be careful with this functionality as it might your program un-quittable.
!! If you know what you are doing and wish to stop seeing these messages, you can disable the \x1b[1mWARN_QUIT_BLOCK\x1b[22m flag at the top of the Object module file.\x1b[0m]]
local STORE_HANDLER_SOURCE = true

-- FLOOF: Fast Lua Object-Oriented Framework
-- Copyright (c) 2026 Matus Kordos

local PATH = (...):match("^(.*)%.object$") or "."
local floof = require(PATH)
local array, vec = floof.array, floof.vector

local error, unpack = error, unpack

local Object = floof:class("Object")

-- function pre-defs

local registerHandler, removeHandler,
      invokeHandlers,
      handlerIterator, iterateHandlers

local add, remove,
      isChildOf,
      ancestors,
      delete

local activeState, setActiveState

local setDepth,
      moveInFront, moveBehind,
      setFrontmost, setBackmost,
      backwards, forwards,
      backToFront, frontToBack,
      forwardActive, backwardActive,
      frontmostActive, backmostActive,
      backwardInHierarchy, backwardInHierarchy,
      hierarchyForwards, hierarchyBackwards
    
local getPointerPos,
      stopHover,
      checkHover, cancelHover,
      shapeChanged

local getPressPosition,
      startPress, movePress, stopPress,
      getPressTarget, setPressTarget,
      pressPointer, movePointer, releasePointer

local addListener, removeListener,
      setListenerPriority,
      listenBefore, listenAfter,
      iterateListener, backtrackListener,
      iterateListeners, backtrackListeners,
      setListeningStatus,
      listenerEvent

local send, sendAll,
      broadcast, broadcastAll

local render

-- private environment

local Object_p = {
    isLoaded = false, isInitialized = false,
    frontmost = nil, backmost = nil,
    isHovered = false,
    ownPointer = false, pointerX = 0, pointerY = 0, hoverTarget = nil,
    presses = array(), pressTargets = {},
    firstListener = nil, lastListener = nil
}
local priv = setmetatable({[Object] = Object_p}, {__mode = "k"})
local proxyOwnership = setmetatable({}, {__mode = "kv"})

local function proxies(self)
    local self_p = priv[self]
    self_p.pressesProxy = self_p.presses:Proxy()
    self_p.pressTargetsProxy = setmetatable({}, {__index = self_p.pressTargets, __newindex = setPressTarget, __metatable = {}})
    proxyOwnership[self_p.pressTargetsProxy] = self
end
proxies(Object)

local function initPrivInstance(self)
    local p = {
        isLoaded = false, isInitialized = false, isDeleted = false,
        parent = nil, hierarchyLevel = 0,
        activeSelf = true, isActive = true,
        z = 0, backward = nil, forward = nil,
        isHovered = false, behindHover = false,
        isPressed = false, presses = array(), pressTargets = {},
        ownPointer = false, pointerX = 0, pointerY = 0, hoverTarget = nil,
        frontmost = nil, backmost = nil,
        isListening = true, listenerPriority = 0,
        previousListener = nil, nextListener = nil
    }
    priv[self] = p
    proxies(self)
    return p
end

local function setRelativeMode() end
local function setMousePosition() end
local function pushGraphics() end
local function popGraphics() end

-- helpers

local function validateObject(self, name, acceptClass)
    local typeStr = acceptClass and "Object instance or the class" or "Object instance"
    if not (acceptClass and self == Object) and
       not floof.instanceOf(self, Object)
    then
        error(("Invalid %s: %s expected, got %s"):format(name, typeStr, floof.typeOf(self)), 3)
    elseif not priv[self] then
        error(("Invalid %s: Object not properly constructed"):format(name), 3)
    elseif priv[self].isDeleted then
        error(("Invalid %s: deleted"):format(name), 3)
    end
end

local function handleCallback(self, func, ...)
    if floof.isCallable(self[func]) then
        local s, e = pcall(self[func], self, ...)
        if not s then error(e, 3) else return e end
    else return self[func] end
end

local function privKeyIterator(k)
    return floof.newIterator(
        function(self)
            return priv[self] and priv[self][k]
        end
    )
end

-- event handlers

local eventHandlers = {} -- [name, firstHandler: {func, next}]

function handlerIterator(event, curr)
    if curr then
        return curr.next
    else
        return eventHandlers[event]
    end
end
function iterateHandlers(event)
    return handlerIterator, event
end
function invokeHandlers(...)
    local who, event
    if ... == Object or floof.subclassOf(..., Object) or floof.instanceOf(..., Object) then
        who, event = ...
    else
        event = ...
    end
    if type(event) ~= "string" then
        error(("Invalid event: string expected, got %s"):format(floof.typeOf(event)), 2)
    end
    for hand in iterateHandlers(event) do
        local s, e
        if not who and not hand.who then
            s, e = pcall(hand.func, select(2, ...))
        elseif who == hand.who or floof.instanceOf(who, hand.who) then
            s, e = pcall(hand.func, who, select(3, ...))
        end
        if s == false then error(e, 3) end
    end
end
Object.invokeHandlers = function(...) return invokeHandlers(...) end

function registerHandler(...)
    local who, event, handler, priority
    if floof.subclassOf(..., Object) or floof.instanceOf(..., Object) then
        who, event, handler, priority = ...
    else
        event, handler, priority = ...
    end
    if type(event) ~= "string" then
        error(("Invalid event: string expected, got %s"):format(floof.typeOf(event)), 2)
    end
    if not floof.isCallable(handler) then
        error(("Invalid handler: callable expected, got %s"):format(floof.typeOf(handler)), 2)
    end
    if priority == nil then
        priority = 0
    elseif type(priority) ~= "number" then
        error(("Invalid priority: number expected, got %s"):format(floof.typeOf(priority)), 2)
    end
    removeHandler(...)
    local newHand = {func = handler, who = who, priority = priority}
    if STORE_HANDLER_SOURCE then
        local info = debug.getinfo(2, "Sl")
        newHand.src = ("%s:%d"):format(info.short_src, info.currentline)
    end
    local hand = eventHandlers[event]
    if not hand or priority > hand.priority then
        eventHandlers[event] = newHand
        newHand.next = hand
        return
    end
    while hand.next do
        if priority > hand.next.priority then
            hand.next, newHand.next = newHand, hand.next
            return
        end
        hand = hand.next
    end
    hand.next = newHand
end
Object.registerHandler = registerHandler

function removeHandler(...)
    local who, event, handler
    if floof.subclassOf(..., Object) or floof.instanceOf(..., Object) then
        who, event, handler = ...
    else
        event, handler = ...
    end
    if type(event) ~= "string" then
        error(("Invalid event: string expected, got %s"):format(floof.typeOf(event)), 2)
    end
    local hand = eventHandlers[event]
    if not hand then return end
    if hand.func == handler and hand.who == who then
        eventHandlers[event] = hand.next
        return
    end
    while hand.next do
        if hand.next.func == handler and hand.next.who == who then
            hand.next = hand.next.next
            return
        end
    end
end
Object.removeHandler = removeHandler

-- public interface

function Object:__init(data, ...)
    if not floof.instanceOf(self, Object) then
        error(("Invalid caller: Object expected, got %s"):format(floof.typeOf(self)), 2)
    end
    if priv[self] then error("Invalid caller: already initialized", 2) end
    if data ~= nil and floof.typeOf(data) ~= "table" then
        error(("Invalid constructor data: table expected, got %s"):format(floof.typeOf(data)), 2)
    end
    local self_p = initPrivInstance(self)
    invokeHandlers(self, "constructed")
    handleCallback(self, "constructed")
    if data then
        for k, v in pairs(data) do
            floof.safeInvoke(floof.set, self, k, v)
        end
    end
    if not self_p.parent then floof.safeInvoke(add, self) end
    self_p.isInitialized = true
    invokeHandlers(self, "initialized")
    handleCallback(self, "initialized")
    if Object_p.isLoaded then
        self_p.isLoaded = true
        invokeHandlers(self, "load", Object_p.arg, Object_p.unfilteredArg)
        handleCallback(self, "load", Object_p.arg, Object_p.unfilteredArg)
    end
    if self_p.parent then
        invokeHandlers(self, "addedto", self_p.parent)
        handleCallback(self, "addedto", self_p.parent)
        invokeHandlers(self_p.parent, "added", self)
        handleCallback(self_p.parent, "added", self)
    else
        invokeHandlers(self, "orphaned")
        handleCallback(self, "orphaned")
    end
    if self_p.isActive then
        invokeHandlers(self, "activated")
        handleCallback(self, "activated")
        if floof.safeInvoke(checkHover, self) then
            local parent_p = priv[self_p.parent] or Object_p
            local old = parent_p.hoverTarget
            parent_p.hoverTarget = self
            if old then floof.safeInvoke(stopHover, old) end
        end
    end
    for i, obj in ipairs{...} do
        if not floof.instanceOf(obj, Object) then
            error(("Invalid child: Object expected, got %s"):format(floof.typeOf(obj)))
        end
        floof.safeInvoke(add, obj, self)
    end
end

function Object:isConstructed() return priv[self] ~= nil end

local getters = {
    isLoaded = priv, isInitialized = priv, isDeleted = priv,
    parent = priv, hierarchyLevel = priv,
    activeSelf = priv, isActive = priv,
    z = priv, backward = priv, forward = priv,
    isHovered = priv, behindHover = priv,
    ownPointer = priv, pointerX = priv, pointerY = priv, hoverTarget = priv,
    isPressed = priv,
    presses = function(self) return priv[self].pressesProxy end,
    pressTargets = function(self) return priv[self].pressTargetsProxy end,
    frontmost = priv, backmost = priv,
    isListening = priv, listenerPriority = priv,
    previousListener = priv, nextListener = priv,
    firstListener = priv, lastListener = priv
}
function Object:__get(k)
    if priv[self] and getters[k] then
        if getters[k] == priv then
            return priv[self][k]
        else
            return floof.safeReturn(getters[k], self)
        end
    end
end

local setters = {}
function Object:__set(k, v)
    if priv[self] and (setters[k] or getters[k]) then
        if not setters[k] then
            error(("Cannot modify private field %q"):format(k), 2)
        else
            return floof.safeReturn(setters[k], self, v)
        end
    else rawset(self, k, v) end
end

-- main loop

local globalEvents = { -- [name, callOnInactive]
    resize = true, displayrotated = true,
    focus = false, mousefocus = false,
    visible = false, exposed = false, occluded = false,
    localechanged = true
}

local touchPresses = {}
function Object.isTouchPress(id) return touchPresses[id] ~= nil end

local function quit(...)
    for hand in iterateHandlers("quit") do
        if floof.safeInvoke(hand.func, ...) then
            local r = "handler"
            if hand.src then
                r = r .. (" @ %s"):format(hand.src)
            end
            return r
        end
    end
    for obj in hierarchyForwards(Object) do
        if handleCallback(obj, "quit", ...) then
            return tostring(obj)
        end
    end
    if floof.safeInvoke(love.quit, ...) then
        return "love"
    end
    for obj in hierarchyForwards(Object) do
        invokeHandlers(obj, "finalize")
        handleCallback(obj, "finalize")
    end
end

local function handleEvent(name, ...)
    if not name then return true end
    if name == "quit" then
        local block = floof.safeInvoke(quit, ...)
        if not block then
            return false, ... or 0
        elseif WARN_QUIT_BLOCK then
            print((QUIT_BLOCK_MESSAGE):format(blockQuit))
        end
    elseif name == "mousepressed" then
        local x, y, button, touch = ...
        if button and not touch then
            if not Object_p.ownPointer then
                floof.safeInvoke(startPress, Object, button, x, y, select(5, ...))
            else
                floof.safeInvoke(listenerEvent, Object, "mousepressed", button, select(5, ...))
            end
        end
    elseif name == "mousemoved" then
        local x, y, dx, dy, touch = ...
        if not touch then
            if not Object_p.ownPointer then
                floof.safeInvoke(movePointer, Object, x, y, dx, dy, select(6, ...))
            else
                floof.safeInvoke(listenerEvent, Object, "mousemoved", dx, dy, select(6, ...))
            end
        end
    elseif name == "mousereleased" then
        local x, y, button, touch = ...
        if button and not touch then
            if not Object_p.ownPointer then
                floof.safeInvoke(stopPress, Object, button, x, y, true, select(5, ...))
            else
                floof.safeInvoke(listenerEvent, Object, "mousereleased", button, select(5, ...))
            end
        end
    elseif name == "wheelmoved" then
        if not Object_p.ownPointer then
            local curr = Object_p.hoverTarget
            while curr do
                local curr_p = priv[curr]
                invokeHandlers(curr, "scrolled", ...)
                if handleCallback(curr, "scrolled", ...)
                or curr_p.ownPointer
                then break end
                curr = curr_p.hoverTarget
            end
        else
            floof.safeInvoke(listenerEvent, Object, "wheelmoved", ...)
        end
    elseif name == "touchpressed" then
        local id, x, y, dx, dy = ...
        touchPresses[id] = vec(x, y)
        floof.safeInvoke(startPress, Object, id, x, y, select(6, ...))
    elseif name == "touchmoved" then
        local id, x, y, dx, dy = ...
        touchPresses[id] = vec(x, y)
        floof.safeInvoke(movePress, Object, ...)
    elseif name == "touchreleased" then
        local id, x, y, dx, dy = ...
        floof.safeInvoke(stopPress, Object, id, x, y, true, select(6, ...))
        touchPresses[a] = nil
    elseif globalEvents[name] ~= nil then
        if name == "mousefocus" then
            Object_p.isHovered = ...
            if not ... and not Object_p.ownPointer and Object_p.hoverTarget then
                local hov = Object_p.hoverTarget
                Object_p.hoverTarget = nil
                floof.safeInvoke(stopHover, hov)
            elseif ... and not Object_p.ownPointer then
                for ch in frontToBack(Object) do
                    if floof.safeInvoke(checkHover, ch) then
                        Object_p.hoverTarget = ch
                    end
                end
            end
        end
        invokeHandlers(name, ...)
        for obj in hierarchyForwards(Object) do
            if (globalEvents[name] or priv[obj].isActive) then
                invokeHandlers(obj, name, ...)
                handleCallback(obj, name, ...)
            end
        end
        floof.safeInvoke(love[name], ...)
    else
        floof.safeInvoke(listenerEvent, Object, name, ...)
    end
end

function Object.initialize(arg)
    if not love then return end

    if arg then
        Object_p.unfilteredArg, Object_p.arg = arg, love.arg.parseGameArguments(arg)
    end

    if love.mouse then
        setRelativeMode, setMousePosition = love.mouse.setRelativeMode, love.mouse.setPosition
        function love.mouse.setRelativeMode(value)
            floof.safeInvoke(setters.ownPointer, Object, value)
        end
        Object_p.pointerX, Object_p.pointerY = love.mouse.getPosition()
        if Object_p.ownPointer then setRelativeMode(true)
        elseif love.mouse.getRelativeMode() then Object_p.ownPointer = true end
    end

    if love.graphics then
        pushGraphics, popGraphics = love.graphics.push, love.graphics.pop
    end

    function love.run()
        Object_p.isLoaded = true
        for obj in hierarchyForwards(Object) do
            priv[obj].isLoaded = true
            invokeHandlers(obj, "load", Object_p.arg, Object_p.unfilteredArg)
            handleCallback(obj, "load", Object_p.arg, Object_p.unfilteredArg)
        end
        if love.timer then love.timer.step() end
        local dt = 0
        return function()
            -- events
            if love.event then
                love.event.pump()
                repeat
                    local s, r = floof.safeInvoke(handleEvent, love.event.poll_i())
                    if s == false then return r end
                until s
            end
            -- update
            if love.timer then dt = love.timer.step() end
            for obj in hierarchyForwards(Object) do
                local obj_p = priv[obj]
                if obj_p.isActive then
                    invokeHandlers(obj, "update", dt)
                    handleCallback(obj, "update", dt)
                end
            end
            invokeHandlers("update", dt)
            floof.safeInvoke(love.update, dt)
            -- draw
            if love.graphics and love.graphics.isActive() then
                love.graphics.origin()
                love.graphics.clear(love.graphics.getBackgroundColor())
                floof.safeInvoke(render, Object)
                love.graphics.present()
            end
            -- timer
            if love.timer then love.timer.sleep(0.001) end
        end
    end
end



-- hierarchy

function add(self, parent)
    validateObject(self, "caller")
    local self_p = priv[self]
    if self_p.isInitialized and self_p.parent == parent then return end
    if parent ~= nil then validateObject(parent, "value") end
    if parent and isChildOf(parent, self) then
        error("Invalid value: cannot be a descendant of the Object", 2)
    end
    if self_p.isInitialized then floof.safeInvoke(remove, self) end
    local parent_p = priv[parent or Object]
    if parent and not parent_p.isActive and self_p.isActive then
        floof.safeInvoke(activeState, self, false)
    elseif not parent and self_p.activeSelf and not self_p.isActive then
        floof.safeInvoke(activeState, self, true)
    end
    self_p.behindHover = false
    if not parent_p.frontmost then
        parent_p.frontmost, parent_p.backmost = self, self
    else
        for sib in forwards(parent_p.frontmost, true) do
            local sib_p = priv[sib]
            if sib_p.z <= self_p.z then
                if not sib_p.backward then
                    self_p.forward, sib_p.backward, parent_p.frontmost = sib, self, self
                else
                    self_p.backward, self_p.forward, priv[sib_p.backward].forward, sib_p.backward = sib_p.backward, sib, self, self
                end
                break
            elseif not sib_p.forward then
                self_p.backward, sib_p.forward, parent_p.backmost = sib, self, self
                break
            end
            if sib_p.isHovered then self_p.behindHover = true end
        end
    end
    if floof.safeInvoke(checkHover, self) then
        local old = parent_p.hoverTarget
        parent_p.hoverTarget = self
        if old then floof.safeInvoke(stopHover, old) end
    end
    self_p.parent = parent
    if parent then
        self_p.hierarchyLevel = parent_p.hierarchyLevel + 1
        if self_p.isInitialized then
            invokeHandlers(self, "addedto", parent)
            handleCallback(self, "addedto", parent)
            invokeHandlers(parent, "added", self)
            handleCallback(parent, "added", self)
        end
    else
        self_p.hierarchyLevel = 0
        if self_p.isInitialized then
            invokeHandlers(self, "orphaned")
            handleCallback(self, "orphaned")
        end
    end
end
Object.setParent, setters.parent = add, add

function remove(self)
    local self_p = priv[self]
    local parent = self_p.parent or Object
    local parent_p = priv[parent]
    for i, press in self_p.presses:iterate() do
        parent_p.pressTargets[press] = nil
        floof.safeInvoke(stopPress, self, press, getPressPosition(self, press))
    end
    if self_p.isInitialized then
        if parent then
            invokeHandlers(self, "removedfrom", parent)
            handleCallback(self, "removedfrom", parent)
            invokeHandlers(parent, "removed", self)
            handleCallback(parent, "removed", self)
        else
            invokeHandlers(self, "adopted")
            handleCallback(self, "adopted")
        end
    end
    floof.safeInvoke(cancelHover, self)
    if self_p.backward then
        priv[self_p.backward].forward = self_p.forward
    else
        parent_p.frontmost = self_p.forward
    end
    if self_p.forward then
        priv[self_p.forward].backward = self_p.backward
    else
        parent_p.backmost = self_p.backward
    end
    self_p.parent, self_p.backward, self_p.forward = nil
    self_p.hierarchyLevel = 0
end

function delete(self)
    validateObject(self, "caller")
    local self_p = priv[self]
    floof.safeInvoke(remove, self)
    if self_p.isInitialized then
        invokeHandlers(self, "deleted")
        handleCallback(self, "deleted")
    end
    priv[self].isDeleted = true
end
Object.delete = delete

function isChildOf(self, other)
    validateObject(self, "caller")
    validateObject(other, "value")
    for p in ancestors(self, true) do if p == other then return true end end
    return false
end
Object.isChildOf = isChildOf

ancestors = privKeyIterator("parent")
Object.ancestors = ancestors

-- state

function activeState(self, state)
    local curr, q, tail = self, {}, self
    while curr do
        local curr_p = priv[curr]
        if curr_p.isActive ~= state then
            curr_p.isActive = state
            if curr_p.isInitialized then
                invokeHandlers(self, state and "activated" or "deactivated")
                handleCallback(self, state and "activated" or "deactivated")
            end
            for ch in frontToBack(curr) do
                q[tail], tail = ch, ch
            end
        end
        curr = q[curr]
    end
end

function setActiveState(self, state)
    validateObject(self, "caller")
    if type(state) ~= "boolean" then
        error(("Invalid value: boolean expected, got %s"):format(floof.typeOf(state)), 2)
    end
    local self_p = priv[self]
    if self_p.activeSelf == state then return end
    self_p.activeSelf = state
    local parent_p = priv[self_p.parent] or Object_p
    if self_p.parent and not parent_p.isActive then return end
    if not state then
        for i, press in self.presses:iterate() do
            parent_p.pressTargets[press] = nil
            floof.safeInvoke(stopPress, self, press, getPressPosition(self, press))
        end
    end
    floof.safeInvoke(activeState, self, state)
    if state then
        if floof.safeInvoke(checkHover, self) then
            local old = parent_p.hoverTarget
            parent_p.hoverTarget = self
            if old then floof.safeInvoke(stopHover, old) end
        end
    elseif self_p.isHovered then floof.safeInvoke(cancelHover, self) end
end
Object.setActiveState, setters.activeSelf = setActiveState, setActiveState

-- depth

function setDepth(self, z)
    validateObject(self, "caller")
    if type(z) ~= "number" then
        error(("Invalid value: number expected, got %s"):format(floof.typeOf(z)), 2)
    end
    local self_p = priv[self]
    self_p.z = z
    local parent = self_p.parent or Object
    local parent_p = priv[parent]
    if self_p.backward and priv[self_p.backward].z <= z then
        for sib in backwards(self) do
            local sib_p = priv[sib]
            if sib_p.z > z then break end
            self_p.backward, sib_p.forward = sib_p.backward, self_p.forward
            if sib_p.backward then
                priv[sib_p.backward].forward = self
            else
                parent_p.frontmost = self
            end
            if self_p.forward then
                priv[self_p.forward].backward = sib
            else
                parent_p.backmost = sib
            end
            sib_p.backward, self_p.forward = self, sib
            if self_p.isHovered then
                sib_p.behindHover = true
            elseif sib_p.isHovered then
                self_p.behindHover = false
                if floof.safeInvoke(checkHover, self) then
                    parent_p.hoverTarget = self
                    floof.safeInvoke(stopHover, sib)
                end
            end
        end
    elseif self_p.forward and priv[self_p.forward].z > z then
        for sib in forwards(self) do
            local sib_p = priv[sib]
            if sib_p.z <= z then break end
            sib_p.backward, self_p.forward = self_p.backward, sib_p.forward
            if self_p.backward then
                priv[self_p.backward].forward = sib
            else
                parent_p.frontmost = sib
            end
            if sib_p.forward then
                priv[sib_p.forward].backward = self
            else
                parent_p.backmost = self
            end
            self_p.backward, sib_p.forward = sib, self
            if self_p.isHovered then
                sib_p.behindHover = false
                if floof.safeInvoke(checkHover, sib) then
                    parent_p.hoverTarget = sib
                    floof.safeInvoke(stopHover, self)
                end
            elseif sib_p.isHovered then
                self_p.behindHover = true
            end
        end
    end
    if self_p.isInitialized then
        invokeHandlers(self, "depthchanged")
        handleCallback(self, "depthchanged")
    end
end
Object.setDepth, setters.z = setDepth, setDepth

function moveInFront(self, forward)
    validateObject(self, "caller")
    if forward ~= nil then validateObject(forward, "value") end
    if self == forward then error("Invalid value: equal to caller", 2) end
    local self_p, forward_p = priv[self], priv[forward]
    if forward and forward_p.parent ~= self_p.parent then
        error("Invalid value: must be a sibling of the caller", 2)
    end
    if self_p.forward == forward then return end
    local parent_p = priv[self_p.parent] or Object_p
    local p_backward = self_p.forward
    if self_p.backward then
        priv[self_p.backward].forward = self_p.forward
    else
        parent_p.frontmost = self_p.forward
    end
    if self_p.forward then
        priv[self_p.forward].backward = self_p.backward
    else
        parent_p.backmost = self_p.backward
    end
    if forward then
        self_p.z = forward_p.z
        if forward_p.backward then
            priv[forward_p.backward].forward = self
        else
            parent_p.frontmost = self
        end
        forward_p.backward = self
    else
        self_p.z = priv[parent_p.backmost].z
        priv[parent_p.backmost].forward, parent_p.backmost = self, self
    end
    if self_p.isHovered and forward_p.behindHover then
        for sib in forwards(p_backward, true) do
            if sib == self then break end
            local sib_p = priv[sib]
            sib_p.behindHover = false
            if floof.safeInvoke(checkHover, sib) then
                parent_p.hoverTarget = sib
                floof.safeInvoke(stopHover, self)
                break
            end
        end
    elseif self_p.behindHover and not forward_p.behindHover then
        self_p.behindHover = false
        if floof.safeInvoke(checkHover, self) then
            local old = parent_p.hoverTarget
            parent_p.hoverTarget = self
            if old then floof.safeInvoke(stopHover, old) end
        end
    end
    if self_p.isInitialized then
        invokeHandlers(self, "depthchanged")
        handleCallback(self, "depthchanged")
    end
end
Object.moveInFront, setters.forward = moveInFront, moveInFront

function moveBehind(self, backward)
    validateObject(self, "caller")
    if backward ~= nil then validateObject(backward, "value") end
    if self == backward then error("Invalid value: equal to caller", 2) end
    local self_p, backward_p = priv[self], priv[backward]
    if backward and backward_p.parent ~= self_p.parent then
        error("Invalid value: must be a sibling of the caller", 2)
    end
    if self_p.backward == backward then return end
    local parent_p = priv[self_p.parent] or Object_p
    local p_backward = self_p.forward
    if self_p.backward then
        priv[self_p.backward].forward = self_p.forward
    else
        parent_p.frontmost = self_p.forward
    end
    if self_p.forward then
        priv[self_p.forward].backward = self_p.backward
    else
        parent_p.backmost = self_p.backward
    end
    if backward then
        self_p.z = backward_p.z
        if backward_p.forward then
            priv[backward_p.forward].backward = self
        else
            parent_p.backmost = self
        end
        backward_p.forward = self
    else
        self_p.z = priv[parent_p.frontmost].z
        priv[parent_p.frontmost].backward, parent_p.frontmost = self, self
    end
    if self_p.isHovered and backward_p.behindHover then
        for sib in forwards(p_backward, true) do
            if sib == self then break end
            local sib_p = priv[sib]
            sib_p.behindHover = false
            if floof.safeInvoke(checkHover, sib) then
                parent_p.hoverTarget = sib
                floof.safeInvoke(stopHover, self)
                break
            end
        end
    elseif self_p.behindHover and not backward_p.isHovered and not backward_p.behindHover then
        self_p.behindHover = false
        if floof.safeInvoke(checkHover, self) then
            local old = parent_p.hoverTarget
            parent_p.hoverTarget = self
            if old then floof.safeInvoke(stopHover, old) end
        end
    end
    if self_p.isInitialized then
        invokeHandlers(self, "depthchanged")
        handleCallback(self, "depthchanged")
    end
end
Object.moveBehind, setters.backward = moveBehind, moveBehind

function setFrontmost(self, frontmost)
    validateObject(self, "caller", true)
    validateObject(frontmost, "value")
    local self_p, frontmost_p = priv[self], priv[frontmost]
    if frontmost.parent ~= self then
        error("Invalid value: must be a child of the caller", 2)
    end
    if self_p.frontmost == frontmost then return end
    floof.safeInvoke(moveInFront, frontmost, self_p.frontmost)
end
Object.moveToFront, setters.frontmost = setFrontmost, setFrontmost

function setBackmost(self, backmost)
    validateObject(self, "caller", true)
    validateObject(backmost, "value")
    local self_p, backmost_p = priv[self], priv[backmost]
    if backmost_p.parent ~= self then
        error("Invalid value: must be a child of the caller", 2)
    end
    if self_p.backmost == backmost then return end
    floof.safeInvoke(moveBehind, backmost, self_p.backmost)
end
Object.moveToBack, setters.backmost = setBackmost, setBackmost

function backwardActive(self)
    repeat
        self = priv[self].backward
    until not self or priv[self].isActive
    return self
end
function forwardActive(self)
    repeat
        self = priv[self].forward
    until not self or priv[self].isActive
    return self
end
getters.backwardActive, getters.forwardActive = backwardActive, forwardActive

function frontmostActive(self)
    local frontmost = priv[self].frontmost
    while frontmost and not priv[frontmost].isActive do
        frontmost = priv[frontmost].forward
    end
    return frontmost
end
function backmostActive(self)
    local backmost = priv[self].backmost
    while backmost and not priv[backmost].isActive do
        backmost = priv[backmost].backward
    end
    return backmost
end
getters.frontmostActive, getters.backmostActive = frontmostActive, backmostActive

backwards = privKeyIterator("backward")
function backToFront(self)
    if priv[self] then
        return backwards(priv[self].backmost, true)
    else
        return rawget, {}
    end
end
Object.backwards, Object.backToFront = backwards, backToFront

forwards = privKeyIterator("forward")
function frontToBack(self)
    if priv[self] then
        return forwards(priv[self].frontmost, true)
    else
        return rawget, {}
    end
end
Object.forwards, Object.frontToBack = forwards, frontToBack

function forwardInHierarchy(self, start)
    local self_p = priv[self]
    if not self_p then return end
    if self_p.frontmost then return self_p.frontmost end
    if self_p.forward   then return self_p.forward   end
    for obj in ancestors(self) do
        if obj == start then return end
        local obj_p = priv[obj]
        if obj_p.forward then return obj_p.forward end
    end
end
hierarchyForwards = floof.newIterator(forwardInHierarchy)
Object.hierarchyForwards, Object.forwardInHierarchy = hierarchyForwards, forwardInHierarchy

function backwardInHierarchy(self, start)
    local self_p = priv[self]
    if not self_p then return end
    if self_p.backmost then return self_p.backmost end
    if self_p.backward then return self_p.backward end
    for obj in ancestors(self) do
        if obj == start then return end
        local obj_p = priv[obj]
        if obj_p.backward then return obj_p.backward end
    end
end
hierarchyBackwards = floof.newIterator(backwardInHierarchy)
Object.hierarchyBackwards, Object.backwardInHierarchy = hierarchyBackwards, backwardInHierarchy

-- pointers

function getPointerPos(self)
    validateObject(self, "caller", true)
    local parent_p = priv[priv[self].parent] or Object_p
    return parent_p.pointerX, parent_p.pointerY
end
Object.getPointerPosition = getPointerPos

function getters:parentPointerX() return (priv[priv[self].parent] or Object_p).pointerX end
function getters:parentPointerY() return (priv[priv[self].parent] or Object_p).pointerY end

function stopHover(self, ...)
    local self_p = priv[self]
    if not self_p.isHovered then return end
    local parent_p = priv[self_p.parent] or Object_p
    local x, y = parent_p.pointerX, parent_p.pointerY
    local curr, curr_p = self, self_p
    while curr do
        curr_p.isHovered = false
        invokeHandlers(curr, "unhovered", x, y, ...)
        handleCallback(curr, "unhovered", x, y, ...)
        if curr_p.ownPointer then break end
        local hov = curr_p.hoverTarget
        curr_p.hoverTarget = nil
        if hov then
            for sib in forwards(hov) do
                priv[sib].behindHover = false
            end
        end
        curr, curr_p = hov, priv[hov]
    end
end

local checkingHover = {}
function checkHover(self, ...)
    if checkingHover[self] then return true end
    local self_p = priv[self]
    local parent = self_p.parent
    local parent_p = priv[parent] or Object_p
    local x, y = parent_p.pointerX, parent_p.pointerY
    if not self_p.isInitialized or not self_p.isActive or
       parent and (not parent_p.isHovered or parent_p.hoverTarget == false) or
       self_p.isHovered or self_p.behindHover or
       not handleCallback(self, "check", x, y)
    then
        return false
    end
    checkingHover[self] = true
    invokeHandlers(self, "hovered", x, y, ...)
    local v = handleCallback(self, "hovered", x, y, ...)
    checkingHover[self] = nil
    if v == false then
        invokeHandlers(self, "unhovered", x, y, ...)
        handleCallback(self, "unhovered", x, y, ...)
        return false
    end
    self_p.isHovered = true
    for sib in forwards(self) do
        local sib_p = priv[sib]
        if sib_p.behindHover then break end
        sib_p.behindHover = true
    end
    if v == true then
        self_p.hoverTarget = false
        return true
    end
    local curr, curr_p = self, self_p
    repeat
        local new, new_p
        for ch in frontToBack(curr) do
            local ch_p = priv[ch]
            if ch_p.isActive and handleCallback(ch, "check", x, y) then
                invokeHandlers(ch, "hovered", x, y, ...)
                local v = handleCallback(ch, "hovered", x, y, ...)
                if v ~= false then
                    curr_p.hoverTarget = ch
                    ch_p.isHovered = true
                    for sib in forwards(ch) do
                        local sib_p = priv[sib]
                        if sib_p.behindHover then break end
                        sib_p.behindHover = true
                    end
                    if v == true then ch_p.hoverTarget = false end
                    new, new_p = ch, ch_p
                    break
                else
                    invokeHandlers(ch, "unhovered", x, y, ...)
                    handleCallback(ch, "unhovered", x, y, ...)
                end
            end
        end
        curr, curr_p = new, new_p
    until not curr or curr_p.ownPointer or curr_p.hoverTarget == false
    return true
end

function cancelHover(self, ...)
    validateObject(self, "caller")
    local self_p = priv[self]
    if not self_p.isHovered then return end
    local new
    for sib in forwards(self) do
        priv[sib].behindHover = false
        if floof.safeInvoke(checkHover, sib, ...) then
            new = sib
            break
        end
    end
    local parent_p = priv[self_p.parent] or Object_p
    parent_p.hoverTarget = new
    floof.safeInvoke(stopHover, self, ...)
end
Object.cancelHover = cancelHover

function shapeChanged(self, ...)
    validateObject(self, "caller")
    local self_p = priv[self]
    local parent = self_p.parent
    local parent_p = priv[parent] or Object_p
    local x, y = parent_p.pointerX, parent_p.pointerY
    if self_p.isHovered then
        if handleCallback(self, "hovermoved", x, y, 0, 0, ...) ~= true and not handleCallback(self, "check", x, y) then
            floof.safeInvoke(cancelHover, self, ...)
        end
    else
        if floof.safeInvoke(checkHover, self, ...) then
            local old = parent_p.hoverTarget
            parent_p.hoverTarget = self
            if old then floof.safeInvoke(stopHover, old) end
        end
    end
    for i, press in self_p.presses:iterate() do
        local x, y = getPressPosition(self, press)
        if handleCallback(self, "dragged", x, y, 0, 0, press, ...) ~= true and not handleCallback(self, "check", x, y) then
            floof.safeInvoke(stopPress, self, press, x, y, false, ...)
        end
    end
end
Object.shapeChanged = shapeChanged

-- presses

function getPressPosition(self, press)
    validateObject(self, "caller", true)
    if press == nil then
        error("Invalid press ID: nil", 2)
    elseif not priv[self].presses:find(press) then
        error(("Invalid press ID (%s): the caller is not currently interacting with this press"):format(tostring(press)), 2)
    end
    if touchPresses[press] then
        return touchPresses[press]:unpack()
    else
        return getPointerPos(self)
    end
end
Object.getPressPosition = getPressPosition

function startPress(self, press, x, y, ...)
    local pointer = touchPresses[press] == nil
    local self_p = priv[self]
    if self == Object then self_p.presses:append(press) end
    local curr, curr_p = self, self_p
    repeat
        local nxt = nil
        for ch in frontToBack(curr) do
            local ch_p = priv[ch]
            if love and curr == Object and ch_p.z < 0 then
                if pointer and
                    floof.safeInvoke(love.mousepressed, x, y, press, false, ...) or
                not pointer and
                    floof.safeInvoke(love.touchpressed, press, x, y, 0, 0, ...)
                then
                    nxt = love
                    break
                end
            end
            if ch_p.isActive and handleCallback(ch, "check", x, y) then
                invokeHandlers(ch, "pressed", x, y, press, not pointer, ...)
                local v = handleCallback(ch, "pressed", x, y, press, not pointer, ...)
                if v ~= false then
                    curr_p.pressTargets[press], nxt = ch, ch
                    ch_p.presses:append(press)
                    ch_p.isPressed = true
                    if v == true then nxt = nil end
                    break
                else
                    invokeHandlers(ch, "cancelled", x, y, press, not pointer, ...)
                    handleCallback(ch, "cancelled", x, y, press, not pointer, ...)
                end
            end
        end
        if love and curr == Object and not nxt then
            if pointer then
                floof.safeInvoke(love.mousepressed, x, y, press, false, ...)
            else
                floof.safeInvoke(love.touchpressed, press, x, y, 0, 0, ...)
            end
        elseif nxt == love then return end
        curr, curr_p = nxt, priv[nxt]
    until not curr or pointer and curr_p.ownPointer
    return true
end

function movePress(self, press, x, y, dx, dy, ...)
    local pointer = touchPresses[press] == nil
    if not priv[self].pressTargets[press] then 
        if love and self == Object and not pointer then
            return floof.safeReturn(love.touchmoved, press, x, y, dx, dy, ...)
        else
            return
        end
    end
    local parent_p = priv[self]
    self = parent_p.pressTargets[press]
    local self_p = priv[self]
    repeat
        invokeHandlers(self, "dragged", x, y, dx, dy, press, not pointer, ...)
        if handleCallback(self, "dragged", x, y, dx, dy, press, not pointer, ...) ~= true
           and not handleCallback(self, "check", x, y)
        then
            parent_p.pressTargets[press] = nil
            floof.safeInvoke(stopPress, self, press, x, y, false, ...)
        end
        parent_p = self_p
        self = parent_p.pressTargets[press]
        self_p = priv[self]
    until not self or pointer and self_p.ownPointer
end

function stopPress(self, press, x, y, proper, ...)
    local pointer = touchPresses[press] == nil
    local self_p = priv[self]
    repeat
        self_p.presses:remove(press)
        if self ~= Object then
            if self_p.presses.length == 0 then self_p.isPressed = false end
            invokeHandlers(self, proper and "released" or "cancelled", x, y, press, not pointer, ...)
            if handleCallback(self, proper and "released" or "cancelled", x, y, press, not pointer, ...) then
                proper = false
            end
        elseif love and proper and not self_p.pressTargets[press] then
            if pointer then
                floof.safeInvoke(love.mousereleased, x, y, press, false, ...)
            else
                floof.safeInvoke(love.touchreleased, press, x, y, 0, 0, ...)
            end
        end
        self = self_p.pressTargets[press]
        self_p.pressTargets[press] = nil
        self_p = priv[self]
    until not self or pointer and self_p.ownPointer
end

function getPressTarget(self, press)
    validateObject(self, "caller", true)
    if press == nil then
        error("Invalid press ID: nil", 2)
    elseif not priv[self].presses:find(press) then
        error(("Invalid press ID (%s): the caller is not currently interacting with this press"):format(tostring(press)), 2)
    end
    return priv[self].pressTargets[press]
end

function setPressTarget(self, press, target, ...)
    if proxyOwnership[self] then self = proxyOwnership[self] end
    validateObject(self, "caller", true)
    if press == nil then
        error("Invalid press ID: nil", 2)
    elseif not priv[self].presses:find(press) then
        error(("Invalid press ID (%s): the caller is not currently interacting with this press"):format(tostring(press)), 2)
    end
    if target ~= nil then
        validateObject(target, "target")
        if priv[target].parent ~= (self ~= Object and self or nil) then
            error("Invalid target: must be a child of the caller", 2)
        elseif not priv[target].isActive then
            error("Invalid target: object is inactive", 2)
        end
    end
    local self_p = priv[self]
    local old = self_p.pressTargets[press]
    local pointer = touchPresses[press] == nil
    local x, y = getPressPosition(self, press)
    if old == target then return true end
    if target then
        invokeHandlers(target, "pressed", x, y, press, not pointer, ...)
        local v = handleCallback(target, "pressed", x, y, press, not pointer, ...)
        if v ~= false then
            self_p.pressTargets[press] = target
            if old then floof.safeInvoke(stopPress, old, press, x, y, false, ...) end
            priv[target].presses:append(press)
            priv[target].isPressed = true
            if v ~= true then floof.safeInvoke(startPress, target, press, x, y, ...) end
        else
            invokeHandlers(target, "cancelled", x, y, press, not pointer, ...)
            handleCallback(target, "cancelled", x, y, press, not pointer, ...)
        end
    elseif not target then
        self_p.pressTargets[press] = nil
        if old then floof.safeInvoke(stopPress, old, press, x, y, false, ...) end
        if love and self == Object then
            if pointer then
                floof.safeInvoke(love.mousepressed, x, y, press, false, ...)
            else
                floof.safeInvoke(love.touchpressed, press, x, y, 0, 0, ...)
            end
        end
    end
end

Object.getPressTarget, Object.setPressTarget = getPressTarget, setPressTarget

function movePointer(self, x, y, dx, dy, ...)
    if love and self == Object and not Object_p.ownPointer then
        floof.safeInvoke(love.mousemoved, x, y, dx, dy, false, ...)
    end
    local self_p = priv[self]
    for press, target in pairs(self_p.pressTargets) do
        if not touchPresses[press] then
            floof.safeInvoke(movePress, self, press, x, y, dx, dy, ...)
        end
    end
    local px, py = self_p.pointerX, self_p.pointerY
    local curr, curr_p = self, self_p
    repeat
        curr_p.pointerX, curr_p.pointerY = x, y
        local hov, old, new = curr_p.hoverTarget
        for ch in frontToBack(curr) do
            local ch_p = priv[ch]
            local wasBehind = ch_p.behindHover
            ch_p.behindHover = false
            if ch_p.isActive then
                if ch == hov then
                    invokeHandlers(ch, "hovermoved", x, y, dx, dy, ...)
                    if handleCallback(ch, "hovermoved", x, y, dx, dy, ...) == true or
                       handleCallback(ch, "check", x, y)
                    then break else old, hov = ch end
                elseif (
                    wasBehind or
                    not handleCallback(ch, "check", px, py)
                ) and floof.safeInvoke(checkHover, ch, ...)
                then old, new, hov = hov, ch break end
            end
        end
        curr_p.hoverTarget = new or hov
        if old then floof.safeInvoke(stopHover, old, ...) end
        curr, curr_p = hov, priv[hov]
    until not curr or curr_p.ownPointer or curr_p.hoverTarget == false
end

function setters:pointerX(x)
    if type(x) ~= "number" then
        error(("Invalid value: number or nil expected, got %s"):format(floof.typeOf(x)), 2)
    end
    local self_p = priv[self]
    if self ~= Object then
        if not self_p.ownPointer then self_p.ownPointer = true end
    else
        if not self_p.ownPointer then setRelativeMode(true) end
    end
    floof.safeInvoke(movePointer, self, x, self_p.pointerY, x - self_p.pointerX, 0)
end
function setters:pointerY(y)
    if type(y) ~= "number" then
        error(("Invalid value: number or nil expected, got %s"):format(floof.typeOf(y)), 2)
    end
    local self_p = priv[self]
    if self ~= Object then
        if not self_p.ownPointer then self_p.ownPointer = true end
    else
        if not self_p.ownPointer then setRelativeMode(true) end
    end
    floof.safeInvoke(movePointer, self, self_p.pointerX, y, 0, y - self_p.pointerY)
end

function Object:movePointer(x, y, ...)
    validateObject(self, "caller", true)
    local self_p = priv[self]
    if x ~= nil or y ~= nil then
        if type(x) ~= "number" then
            error(("Invalid x value: number or nil expected, got %s"):format(floof.typeOf(x)), 2)
        end
        if type(y) ~= "number" then
            error(("Invalid y value: number or nil expected, got %s"):format(floof.typeOf(y)), 2)
        end
    end
    if not x then
        if self ~= Object then
            if self_p.ownPointer then self_p.ownPointer = false end
            local parent_p = priv[self_p.parent] or Object_p
            x, y = parent_p.pointerX, parent_p.pointerY
        else
            if self_p.ownPointer then setRelativeMode(false) end
            x, y = self_p.pointerX, self_p.pointerY
        end
    else
        if self ~= Object then
            if not self_p.ownPointer then self_p.ownPointer = true end
        else
            if not self_p.ownPointer then setRelativeMode(true) end
        end
    end
    floof.safeInvoke(movePointer,
        self,
        x, y,
        x - self_p.pointerX, y - self_p.pointerY,
        ...
    )
end

function pressPointer(self, press, ...)
    validateObject(self, "caller", true)
    local self_p = priv[self]
    if press == nil then
        error("Invalid press ID: nil", 2)
    elseif touchPresses[press] then
        error(("Invalid press ID (%s): this ID is currently associated with a touch-press"):format(tostring(press)), 2)
    elseif not self_p.ownPointer then
        error("Forbidden: only objects with a self-owned can manually register presses", 2)
    elseif self_p.pressTargets[press] then
        error(("Invalid press ID (%s): a press with this ID is already active"):format(tostring(press)), 2)
    end
    local x, y = getPointerPos(self)
    floof.safeInvoke(startPress, self, press, x, y, ...)
end

function releasePointer(self, press, ...)
    validateObject(self, "caller", true)
    local self_p = priv[self]
    if press == nil then
        error("Invalid press ID: nil", 2)
    elseif touchPresses[press] then
        error("Invalid press ID: this ID is currently associated with a touch-press", 2)
    elseif not self_p.ownPointer then
        error("Forbidden: only objects with a self-owned can manually register presses", 2)
    end
    local t = self_p.pressTargets[press]
    self_p.pressTargets[press] = nil
    if t then floof.safeInvoke(stopPress, t, press, x, y, true, ...) end
    return t
end

Object.pressPointer, Object.releasePointer = pressPointer, releasePointer

function setters:ownPointer(value)
    if type(value) ~= "boolean" then
        error(("Invalid value: boolean expected, got %s"):format(floof.typeOf(value)), 2)
    end
    local self_p = priv[self]
    if self_p.ownPointer == value then return end
    self_p.ownPointer = value
    if self == Object then
        setRelativeMode(value)
        if not value then setMousePosition(self_p.pointerX, self_p.pointerY) end
    end
    for press, obj in pairs(self_p.pressTargets) do
        if not touchPresses[press] then
            self_p.pressTargets[press] = nil
            floof.safeInvoke(stopPress, obj, press, self_p.pointerX, self_p.pointerY, false)
        end
    end
end

-- input

function addListener(self)
    validateObject(self, "caller")
    local self_p = priv[self]
    if self_p.isListener then return end
    self_p.isListener = true
    if not Object.firstListener then
        Object_p.firstListener, Object_p.lastListener = self, self
        return
    end
    for ls in backtrackListeners() do
        local ls_p = priv[ls]
        if ls_p.listenerPriority >= self_p.listenerPriority then
            if ls_p.nextListener then
                priv[ls_p.nextListener].previousListener = self
            else
                Object_p.lastListener = self
            end
            self_p.previousListener, self_p.nextListener = ls, ls_p.nextListener
            ls_p.nextListener = self
        elseif not ls_p.previousListener then
            Object_p.firstListener = self
            self_p.previousListener, self_p.nextListener = nil, ls
            ls_p.previousListener = self
        end
    end
end

function removeListener(self)
    validateObject(self, "caller")
    local self_p = priv[self]
    if not self_p.isListener then return end
    self_p.isListener = false
    if self_p.previousListener then
        priv[self_p.previousListener].nextListener = self_p.nextListener
    else
        Object_p.firstListener = self_p.nextListener
    end
    if self_p.nextListener then
        priv[self_p.nextListener].previousListener = self_p.previousListener
    else
        Object_p.lastListener = self_p.previousListener
    end
    self_p.previousListener, self_p.nextListener = nil, nil
end

Object.addListener, Object.removeListener = addListener, removeListener

function setters:isListener(value)
    validateObject(self, "caller")
    if type(value) ~= "boolean" then
        error(("Invalid value: boolean expected, got %s"):format(floof.typeOf(self)), 2)
    end
    if value then
        floof.safeInvoke(addListener, self)
    else
        floof.safeInvoke(removeListener, self)
    end
end

function setListenerPriority(self, value)
    validateObject(self, "caller")
    if type(value) ~= "number" then
        error(("Invalid value: number expected, got %s"):format(floof.typeOf(self)), 2)
    end
    local self_p = priv[self]
    self_p.listenerPriority = value
    if self_p.isListener then
        if self_p.previousListener and value > priv[self_p.previousListener].listenerPriority then
            for nxt in backtrackListener(self) do
                local nxt_p = priv[nxt]
                local prv = nxt_p.previousListener
                local prv_p = priv[prv]
                if not prv or prv_p.listenerPriority >= value then
                    priv[self_p.previousListener].nextListener = self_p.nextListener
                    if self_p.nextListener then
                        priv[self_p.nextListener].previousListener = self_p.previousListener
                    else
                        Object_p.lastListener = self_p.previousListener
                    end
                    self_p.previousListener, self_p.nextListener, nxt_p.previousListener = prv, nxt, self
                    if prv then
                        prv_p.nextListener = self
                    else
                        Object_p.firstListener = self
                    end
                    break
                end
            end
        elseif self_p.nextListener and value < priv[self_p.nextListener].listenerPriority then
            for prv in iterateListener(self) do
                local prv_p = priv[prv]
                local nxt = prv_p.nextListener
                local nxt_p = priv[nxt]
                if not nxt or nxt_p.listenerPriority <= value then
                    priv[self_p.nextListener].previousListener = self_p.previousListener
                    if self_p.previousListener then
                        priv[self_p.previousListener].nextListener = self_p.nextListener
                    else
                        Object_p.firstListener = self_p.nextListener
                    end
                    self_p.previousListener, self_p.nextListener, prv_p.nextListener = prv, nxt, self
                    if nxt then
                        nxt_p.previousListener = self
                    else
                        Object_p.lastListener = self
                    end
                    break
                end
            end
        end
    end
end
Object.setListenerPriority, setters.listenerPriority = setListenerPriority, setListenerPriority

function listenBefore(self, nextListener)
    validateObject(self, "caller")
    if nextListener ~= nil then
        validateObject(nextListener, "value")
        if not priv[nextListener].isListener then
            error("Invalid value: not a registered listener", 2)
        end
    end
    local self_p = priv[self]
    if self_p.nextListener == nextListener then return end
    if self_p.isListener then
        if self_p.previousListener then
            priv[self_p.previousListener].nextListener = self_p.nextListener
        else
            Object_p.firstListener = self_p.nextListener
        end
        if self_p.nextListener then
            priv[self_p.nextListener].previousListener = self_p.previousListener
        else
            Object_p.lastListener = self_p.previousListener
        end
    else
        self_p.isListener = true
    end
    if nextListener then
        local nextListener_p = priv[nextListener]
        if nextListener_p.previousListener then
            priv[nextListener_p.previousListener].nextListener = self
        else
            Object_p.firstListener = self
        end
        self_p.previousListener, self_p.nextListener, nextListener_p.previousListener = nextListener_p.previousListener, nextListener, self
    else
        self_p.previousListener, self_p.nextListener, Object_p.lastListener = Object_p.lastListener, nil, self
    end
end
Object.listenBefore, setters.nextListener = listenBefore, listenBefore

function listenAfter(self, previousListener)
    validateObject(self, "caller")
    if previousListener ~= nil then
        validateObject(previousListener, "value")
        if not priv[previousListener].isListener then
            error("Invalid value: not a registered listener", 2)
        end
    end
    local self_p = priv[self]
    if self_p.previousListener == previousListener then return end
    if self_p.isListener then
        if self_p.previousListener then
            priv[self_p.previousListener].nextListener = self_p.nextListener
        else
            Object_p.firstListener = self_p.nextListener
        end
        if self_p.nextListener then
            priv[self_p.nextListener].previousListener = self_p.previousListener
        else
            Object_p.lastListener = self_p.previousListener
        end
    else
        self_p.isListener = true
    end
    if previousListener then
        local previousListener_p = priv[previousListener]
        if previousListener_p.nextListener then
            priv[previousListener_p.nextListener].previousListener = self
        else
            Object_p.lastListener = self
        end
        self_p.previousListener, self_p.nextListener, previousListener_p.nextListener = previousListener, previousListener_p.nextListener, self
    else
        self_p.previousListener, self_p.nextListener, Object_p.firstListener = nil, Object_p.firstListener, self
    end
end
Object.listenAfter, setters.previousListener = listenAfter, listenAfter

function setters:firstListener(obj)
    if self ~= Object then
        error(("Forbidden: the %q field can only be modified on the Object class"):format("firstListener"), 2)
    end
    floof.safeInvoke(listenAfter, obj)
end
function setters:lastListener(obj)
    if self ~= Object then
        error(("Forbidden: the %q field can only be modified on the Object class"):format("lastListener"), 2)
    end
    floof.safeInvoke(listenBefore, obj)
end

iterateListener = privKeyIterator("nextListener")
function iterateListeners() return iterateListener(Object_p.firstListener, true) end
Object.iterateListener, Object.iterateListeners = iterateListener, iterateListeners

backtrackListener = privKeyIterator("previousListener")
function backtrackListeners() return backtrackListener(Object_p.lastListener, true) end
Object.backtrackListener, Object.backtrackListeners = backtrackListener, backtrackListeners

function listeningStatus(self, value)
    validateObject(self, "caller")
    if type(value) ~= "boolean" then
        error(("Invalid value: boolean expected, got %s"):format(floof.typeOf(self)), 2)
    end
    priv[self].isListening = value and true or false
end
Object.setListeningStatus, setters.isListening = listeningStatus, listeningStatus

function listenerEvent(self, name, ...)
    validateObject(self, "caller", true)
    local handleLove = self == Object and love ~= nil
    for ls in iterateListener(self == Object and Object_p.firstListener or self, self == Object) do
        local ls_p = priv[ls]
        if handleLove and ls_p.listenerPriority < 0 then
            handleLove = false
            floof.safeInvoke(love[name], ...)
        end
        if ls_p.isActive and ls_p.isListening then
            invokeHandlers(ls, name, ...)
            handleCallback(ls, name, ...)
        end
    end
    if handleLove and name then 
        invokeHandlers(name, ...)
        floof.safeInvoke(love[name], ...)
    end
end
Object.listenerEvent = listenerEvent

-- messaging

function Object:call(name, ...)
    validateObject(self, "caller")
    return floof.safeReturn(self[name], self, ...)
end

function send(self, name, ...)
    validateObject(self, "caller", true)
    for obj in frontToBack(self) do
        if priv[obj].isActive then floof.safeInvoke(obj[name], obj, ...) end
    end
end
function sendAll(self, name, ...)
    validateObject(self, "caller", true)
    for obj in frontToBack(self) do
        floof.safeInvoke(obj[name], obj, ...)
    end
end
Object.send, Object.sendAll = send, sendAll

function broadcast(self, name, ...)
    validateObject(self, "caller", true)
    for obj in hierarchyForwards(self) do
        if priv[obj].isActive then floof.safeInvoke(obj[name], obj, ...) end
    end
end
function broadcastAll(self, name, ...)
    validateObject(self, "caller", true)
    for obj in hierarchyForwards(self) do
        floof.safeInvoke(obj[name], obj, ...)
    end
end
Object.broadcast, Object.broadcastAll = broadcast, broadcastAll

-- graphics

function render(self)
    validateObject(self, "caller", true)
    local drawn, curr = {}, self ~= Object and self or backmostActive(self)
    while curr do
        local curr_p = priv[curr]
        if curr ~= self and curr_p.z >= 0 then
            if curr_p.parent and not drawn[curr_p.parent] then
                pushGraphics("all")
                handleCallback(curr_p.parent, "draw")
                popGraphics()
                drawn[curr_p.parent] = true
            elseif love and self == Object and not curr_p.parent and not drawn[love] then
                pushGraphics("all")
                floof.safeInvoke(love.draw)
                popGraphics()
                drawn[love] = true
            end
        end
        while true do
            pushGraphics("all")
            handleCallback(curr, "predraw")
            local backmost = backmostActive(curr)
            if backmost then curr = backmost else break end
        end
        while curr do
            if not drawn[curr] then
                pushGraphics("all")
                handleCallback(curr, "draw")
                popGraphics()
                drawn[curr] = true
            end
            handleCallback(curr, "postdraw")
            popGraphics()
            if curr == self then break end
            local backward = backwardActive(curr)
            if backward then curr = backward break end
            curr = priv[curr].parent
        end
        if curr == self then break end
    end
    if love and self == Object and not drawn[love] then
        pushGraphics("all")
        floof.safeInvoke(love.draw)
        popGraphics()
    end
end
Object.render = render

return Object