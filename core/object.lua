local _PATH = (...):match("(.-)[^%.]+$")
local array = require(_PATH .. ".array")
local class = require(_PATH .. ".class")
local input = require(_PATH .. ".input")
local hitbox = require(_PATH .. ".hitbox")

-- Object identification and management
local objects = setmetatable({}, {__mode = "k"})
local function isObject(value) 
    return value and objects[value] ~= nil 
end

-- Callback names that objects can implement
local callbackNames = {
    "resize", "update", "predraw", "draw", "postdraw", "quit",
    "created", "deleted", "added", "removed", "addedto", "removedfrom",
    "activated", "deactivated", "childactivated", "childdeactivated",
    "enabled", "disabled"
}

-- Object internal data structure
local function createObjectInternal()
    return {
        name = "",
        class = nil,
        callbacks = {},
        check = nil,
        parent = nil,
        childRegister = {},
        children = array.new(),
        z = 0,
        enabled = true,
        active = nil,
        indexes = array.new(),
        needsSort = false,
        -- Input state
        presses = array.new(),
        pressedObject = {},
        pressedObjectProxy = nil
    }
end

-- Helper function to get object internal data
local function getObjectInternal(obj)
    return objects[obj] and objects[obj].internal
end

-- Object property getters and setters
local objectProperties = {
    parent = {
        get = function(self)
            local internal = objects[self].internal
            return internal.parent
        end,
        set = function(self, value)
            local internal = objects[self].internal
            if internal.parent == value then return end
            
                    if value ~= nil and not isObject(value) then
            error(("Parent must be a FLOOF object (got: %s (%s)). Use floof.new() to create objects."):format(tostring(value), type(value)), 3)
        end
            
            if self == value then
                error(("Cannot assign object as its own parent"), 3)
            end
            
            if value and value:isChildOf(self) then
                error(("Cannot assign object as the parent of its current parent"), 3)
            end
            
            -- Deactivate in all parent objects
            local e = internal.parent
            while e do
                if value and value:isChildOf(e) then break end
                if e.activeChild == self then
                    e.activeChild = nil
                end
                e = e.parent
            end
            
            local p = internal.parent
            internal.parent = value
            
            if p then
                p:updateChildStatus(self)
                p:removed(self)
                self:removedfrom(p)
            end
            
            if value then
                value:updateChildStatus(self)
                value:added(self)
                self:addedto(value)
            end
        end
    },
    
    children = {
        get = function(self)
            local internal = objects[self].internal
            -- Ensure children are sorted if needed
            if internal.needsSort then
                self:refreshChildren()
            end
            local children = array.new()
            for i, e in ipairs(internal.children) do
                children:append(e)
            end
            return children
        end,
        set = function(self, value)
                    if type(value) ~= "table" then
            error(("Children must be a table of FLOOF objects (got: %s (%s)). Use floof.new() to create objects."):format(tostring(value), type(value)), 3)
        end
            for i, v in ipairs(value) do
                if not isObject(v) then
                    error(("Non-FLOOF object at index %d: %s (%s). Use floof.new() to create objects."):format(i, tostring(v), type(v)), 3)
                end
                if self:isChildOf(v) then
                    error(("Cannot assign object as a child of its child"), 3)
                end
                v.parent = self
            end
        end
    },
    
    z = {
        get = function(self)
            local internal = objects[self].internal
            return internal.z
        end,
        set = function(self, value)
            local internal = objects[self].internal
            if type(value) ~= "number" then
                error(("Z value must be a number (got: %s (%s))"):format(tostring(value), type(value)), 3)
            end
            if internal.z == value then return end
            internal.z = value
            if self.parent then 
                self.parent.internal.needsSort = true
            end
        end
    },
    
    enabledSelf = {
        get = function(self)
            local internal = objects[self].internal
            return internal.enabled
        end,
        set = function(self, value)
            if type(value) ~= "boolean" then
                error(("Enabled state must be a boolean value (got: %s (%s))"):format(tostring(value), type(value)), 3)
            end
            local internal = objects[self].internal
            if internal.enabled == value then return end
            internal.enabled = value
            if value then
                self:enabled()
            else
                self:disabled()
            end
        end
    },
    
    isEnabled = {
        get = function(self)
            local internal = objects[self].internal
            if not internal.enabled then
                return false
            elseif internal.parent then
                return internal.parent.isEnabled
            end
            return true
        end
    },
    
    activeChild = {
        get = function(self)
            local internal = objects[self].internal
            return internal.active
        end,
        set = function(self, value)
            local internal = objects[self].internal
            if internal.active == value then return end
            
            if not isObject(value) and value ~= nil then
                error(("Active child must be an object (got: %s (%s))"):format(tostring(value), type(value)), 3)
            end
            
            if value ~= nil and not value:isChildOf(self) then
                error(("Active child must be a child of the object"), 3)
            end
            
            if internal.active then
                internal.active:deactivated()
                self:childdeactivated(internal.active)
            end
            
            internal.active = value
            
            if value then
                value:activated()
                self:childactivated(value)
            end
        end
    },
    
    indexes = {
        get = function(self)
            local internal = objects[self].internal
            return internal.indexes
        end
    }
}

-- Add input properties
for k, v in pairs(input.properties) do
    objectProperties[k] = v
end

-- Add input methods
for k, v in pairs(input.methods) do
    objectMethods[k] = v
end

-- Object methods
local objectMethods = {
    updateChildStatus = function(self, object)
        if not isObject(object) then
            error(("Invalid object (got: %s (%s))"):format(tostring(object), type(object)), 3)
        end
        local internal = objects[self].internal
        if object.parent == self then
            internal.childRegister[object] = true
        else
            internal.childRegister[object] = nil
        end
        self:rebuildChildren()
    end,
    
    rebuildChildren = function(self)
        local internal = objects[self].internal
        internal.children = array.new()
        for child in pairs(internal.childRegister) do
            internal.children:append(child)
        end
        -- Mark as needing sort
        internal.needsSort = true
    end,
    
    refreshChildren = function(self)
        local internal = objects[self].internal
        if internal.needsSort then
            -- Sort by z-index (highest first)
            table.sort(internal.children, function(childA, childB) return childA.z > childB.z end)
            internal.needsSort = false
        end
    end,
    
    addChild = function(self, child)
        if not isObject(child) then
            error(("Invalid child object (got: %s (%s))"):format(tostring(child), type(child)), 3)
        end
        child.parent = self
        return child
    end,
    
    removeChild = function(self, child)
        if not isObject(child) then
            error(("Invalid child object (got: %s (%s))"):format(tostring(child), type(child)), 3)
        end
        if child.parent == self then
            child.parent = nil
        end
        return child
    end,
    

    
    setParent = function(self, parent)
        self.parent = parent
        return self
    end,
    
    isChildOf = function(self, object)
        if not isObject(object) then
            error(("Invalid object (got: %s (%s))"):format(tostring(object), type(object)), 3)
        end
        local currentParent = self.parent
        while currentParent do
            if currentParent == object then return true end
            currentParent = currentParent.parent
        end
        return false
    end,
    
    send = function(self, message, ...)
        -- Check if message is not a callback or internal function
        if callbackNames[message] or objectMethods[message] or objectProperties[message] then
            error(("Cannot send message %q - it is a reserved name"):format(message), 3)
        end
        
        -- Send message to all children that have the function
        for _, child in ipairs(self.children) do
            if child.isEnabled then
                local func = child[message]
                if type(func) == "function" then
                    func(child, ...)
                end
            end
        end
    end,
    
    broadcast = function(self, message, ...)
        -- Check if message is not a callback or internal function
        if callbackNames[message] or objectMethods[message] or objectProperties[message] then
            error(("Cannot broadcast message %q - it is a reserved name"):format(message), 3)
        end
        
        -- Broadcast message to all children that have the function
        for _, child in ipairs(self.children) do
            if child.isEnabled then
                local func = child[message]
                if type(func) == "function" then
                    func(child, ...)
                    -- Recursively broadcast to children
                    child:broadcast(message, ...)
                end
            end
        end
    end
}

-- Default object callbacks
local defaultCallbacks = {
    resize = function(self, width, height)
        for index, child in ipairs(self.children) do
            child:resize(width, height)
        end
    end,
    
    update = function(self, deltaTime)
        -- Handle hover state changes
        local internal = objects[self].internal
        if internal.lastHovered ~= self.hoveredChild then
            if internal.lastHovered then
                internal.lastHovered:unhovered()
            end
            if self.hoveredChild then
                self.hoveredChild:hovered()
            end
            internal.lastHovered = self.hoveredChild
        end
        
        for index, child in ipairs(self.children) do
            if child.isEnabled then
                child:update(deltaTime)
            end
        end
    end,
    
    draw = function(self)
        -- Custom draw callback that handles predraw/postdraw
        local internal = objects[self].internal
        local preDraw = internal.callbacks.predraw or (self.class and self.class.predraw)
        local drawCallback = internal.callbacks.draw or (self.class and self.class.draw)
        local postDraw = internal.callbacks.postdraw or (self.class and self.class.postdraw)
        
        love.graphics.push("all")
        
        if preDraw then preDraw(self) end
        
        local hasDrawn = false
        local children = self.children
        for index = #children, 1, -1 do
            local child = children[index]
            if child.z >= 0 and not hasDrawn then
                if not hasDrawn and drawCallback then
                    drawCallback(self)
                end
                hasDrawn = true
            end
            if child.isEnabled then
                love.graphics.push("all")
                child:draw()
                love.graphics.pop()
            end
        end
        
        if not hasDrawn and drawCallback then
            drawCallback(self)
        end
        
        if postDraw then postDraw(self) end
        
        love.graphics.pop()
    end,
    
    quit = function(self)
        for index, child in ipairs(self.children) do
            child:quit()
        end
    end
}

-- Add input callbacks
for k, v in pairs(input.defaultCallbacks) do
    defaultCallbacks[k] = v
end

-- Create default callbacks for all callback names
for index, name in ipairs(callbackNames) do
    callbackNames[name] = index
    if not defaultCallbacks[name] then
        defaultCallbacks[name] = function(self, ...)
            -- Route to children
            for childIndex, child in ipairs(self.children) do
                if child.isEnabled then
                    local callback = child[name]
                    if callback then callback(child, ...) end
                end
            end
        end
    end
end

-- Object metatable
local objectMt = {
    __index = function(t, k)
        local ref = objects[t]
        if not ref then return end
        
        return k == "class" and ref.internal.class or
               k == "check" and (ref.internal.check or ref.internal.class and ref.internal.class.check or hitbox.checks.default) or
               objectProperties[k] and objectProperties[k].get and objectProperties[k].get(t) or
               objectMethods[k] or
               defaultCallbacks[k] or
               ref.internal.callbacks[k] or
               ref.internal.class and ref.internal.class[k]
    end,
    
    __newindex = function(t, k, v)
        local ref = objects[t]
        if not ref then return end
        
        if k == "class" then
            error("Cannot change an object's class after construction", 2)
        elseif k == "check" then
            if v == nil then
                ref.internal.check = nil
            elseif type(v) == "boolean" then
                ref.internal.check = function() return v end
            elseif type(v) == "function" then
                ref.internal.check = v
            else
                error(("Cannot assign non-function value to %q (got: %s (%s))"):format(k, tostring(v), type(v)), 2)
            end
        elseif objectMethods[k] or class[k] then
            error(("Cannot override the %q method"):format(tostring(k)), 2)
        elseif objectProperties[k] then
            if objectProperties[k].set then
                objectProperties[k].set(t, v)
            else
                error(("Cannot modify the %q field"):format(tostring(k)), 2)
            end
        elseif callbackNames[k] then
            if v == nil then
                ref.internal.callbacks[k] = nil
            elseif type(v) == "boolean" then
                ref.internal.callbacks[k] = function() return v end
            elseif type(v) == "function" then
                ref.internal.callbacks[k] = v
            else
                error(("Cannot assign non-function value to %q (got: %s (%s))"):format(k, tostring(v), type(v)), 2)
            end
        else
            rawset(t, k, v)
        end
    end,
    
    __metatable = {},
    __tostring = function(t)
        local ref = objects[t]
        if not ref then return end
        return type(t.tostring) == "function" and t:tostring() or
               type(t.tostring) == "string" and t.tostring or
               ("%s: %s"):format(t.class and t.class.name or "object", ref.internal.name)
    end
}

-- Object constructor
local function newObject(object, class, ...)
    object = type(object) == "table" and object or {}
    
    if not pcall(setmetatable, object, nil) then
        error("Objects with custom metatables are not supported. If you want to implement an indexing metatable/metamethod, use the 'indexes' field", 2)
    end
    
    -- Create internal reference
    local ref = {
        internal = createObjectInternal()
    }
    objects[object] = ref
    
    -- Copy data before transforming
    local data = {}
    for k, v in pairs(object) do 
        data[k], object[k] = v 
    end
    
    setmetatable(object, objectMt)
    
    -- Set class
    ref.internal.class = class
    ref.internal.name = data.name or tostring(object):match("table: (.+)") or tostring(object)
    
    -- Copy data back (except parent which is handled specially)
    for k, v in pairs(data) do
        if k ~= "parent" then
            local s, e = pcall(function() rawset(object, k, v) end)
            if not s then error(e, 2) end
        end
    end
    
    -- Initialize parent (defaults to root if available)
    if data.parent then
        object.parent = data.parent
    end
    
    -- Call constructor
    if type(object.init) == "function" then
        object:init(...)
    end
    
    -- Initialize screen dimensions if LOVE2D is available
    if love and love.graphics then
        object:resize(love.graphics.getDimensions())
    end
    
    return object
end

return {
    is = isObject,
    new = newObject,
    getInternal = getObjectInternal,
    callbackNames = callbackNames
} 