local PATH = (...):match("^(.+%.).-$") or ""
local Object = require(PATH .. "object")
local array = require(PATH .. "array")

local Element = Object:derive("Element")

Element.directions    = array("vertical", "horizontal")
Element.justifyModes  = array("start", "center", "end", "stretch","space", "even")
Element.alignModes    = array("start", "center", "end", "stretch")

function Element:init(data)
    data = data or {}

    self._elements = array()
    self.clip = data.clip

    self.inLayout = data.inLayout
    self.direction = data.direction
    self.justify = data.justify
    self.align = data.align
    self.alignSelf = data.alignSelf
    self.alignSelfX = data.alignSelfX
    self.alignSelfY = data.alignSelfY
    
    self.width = data.width
    self.height = data.height
    self.minWidth = data.minWidth
    self.minHeight = data.minHeight
    self.maxWidth = data.maxWidth
    self.maxHeight = data.maxHeight
    self.stretchWeight = data.stretchWeight
    
    self.spacing = data.spacing

    self.padding  = data.padding
    self.paddingX = data.paddingX
    self.paddingY = data.paddingY
    self.paddingL = data.paddingL
    self.paddingT = data.paddingT
    self.paddingR = data.paddingR
    self.paddingB = data.paddingB

    self.margin  = data.margin
    self.marginX = data.marginX
    self.marginY = data.marginY
    self.marginL = data.marginL
    self.marginT = data.marginT
    self.marginR = data.marginR
    self.marginB = data.marginB
    
    self.scrollX = 0
    self.scrollY = 0
    self.scrollSpeed = data.scrollSpeed

    Element.super.init(self, data)

    if data.elements then
        for i, elem in ipairs(data.elements) do
            pcall(self.append, self, elem)
        end
    end
end

Element._dirty = {}

function Element:__get_dirty(self)
    return Element._dirty[self] and true or false
end

function Element:__set_dirty(self, value)
    Element._dirty[self] = value and true or false
end

function Element:__get_clip(self)
    return self._clip
end

function Element:__set_clip(self, value)
    self._clip = value and true or false
end

function Element:added(child)
    if Element:isClassOf(child) and not self._elements:find(child) then
        self._elements:append(child)
        self.dirty = true
    end
end

function Element:removed(child)
    if Element:isClassOf(child) and self._elements:find(child) then
        self._elements:remove(child)
        self.dirty = true
    end
end

function Element:append(child)
    if not Element:isClassOf(child) then
        error("Appended value must be an Element: " .. tostring(child) .. " (" .. type(child) .. ")", 2)
    end
    if self:isChildOf(child) then
        error("Attempted to append an element to a descendant of itself", 2)
    end
    if child.parent == self then
        error("Attempted to append an Element that is already a child of this Element", 2)
    end
    self._elements:append(child)
    child.parent = self
end

function Element:remove(child)
    if Element:isClassOf(child) and child.parent == self then
        self._elements:remove(child)
        child.parent = nil
    end
end

function Element:insert(child, before)
    if not Element:isClassOf(child) then
        error("Inserted value must be an Element: " .. tostring(child) .. " (" .. type(child) .. ")", 2)
    end
    if self:isChildOf(child) then
        error("Attempted to insert an Element as a child of itself", 2)
    end
    if child.parent == self then
        error("Attempted to insert an Element that is already a child of this Element" , 2)
    end
    if not Element:isClassOf(before) then
        error("Insertion anchor must be an Element: " .. tostring(before) .. " (" .. type(before) .. ")", 2)
    end
    if before.parent ~= self then
        error("Insertion anchor must be a direct child of this Element", 2)
    end
    self._elements:insert(child, self._elements:find(before))
    child.parent = self
end

function Element:__get_elements(self)
    return self._elements:copy()
end

function Element:__get_inLayout(self)
    return self._inLayout
end

function Element:__set_inLayout(self, value)
    if value == nil and self ~= Element then
        self._inLayout = nil
        return
    end
    if type(value) == "boolean" then
        self._inLayout = value
    else
        error("Attempted to set inLayout to an invalid value: " .. tostring(value) .. " (" .. type(value) .. ")", 2)
    end
    if Element:isClassOf(self.parent) then
        self.parent.dirty = true
    end
end

function Element:__get_direction(self)
    return self._direction
end

function Element:__set_direction(self, value)
    if value == nil and self ~= Element then
        self._direction = nil
        return
    end
    if Element.directions:find(value) then
        self._direction = value
    else
        error("Attempted to set direction to an invalid value: " .. tostring(value) .. ", (available values: " .. table.concat(Element.directions, ", ") .. ")", 2)
    end
    self.dirty = true
end

function Element:__get_justify(self)
    return self._justify
end

function Element:__set_justify(self, value)
    if value == nil and self ~= Element then
        self._justify = nil
        return
    end
    if Element.justifyModes:find(value) then
        self._justify = value
    else
        error("Attempted to set justify to an invalid value: " .. tostring(value) .. ", (available values: " .. table.concat(Element.justifyModes, ", ") .. ")", 2)
    end
    self.dirty = true
end

function Element:__get_align(self)
    return self._align
end

function Element:__set_align(self, value)
    if value == nil and self ~= Element then
        self._align = nil
        return
    end
    if Element.alignModes:find(value) then
        self._align = value
    else
        error("Attempted to set align to an invalid value: " .. tostring(value) .. ", (available values: " .. table.concat(Element.alignModes, ", ") .. ")", 2)
    end
end

function Element:__get_alignSelf(self)
    return self._alignSelf or Element:isClassOf(self.parent) and self.parent.alignSelf or self.class.align
end

function Element:__set_alignSelf(self, value)
    if value == nil and self ~= Element then
        self._alignSelf = nil
        return
    end
    if Element.alignModes:find(value) then
        self._alignSelf = value
    else
        error("Attempted to set alignSelf to an invalid value: " .. tostring(value) .. ", (available values: " .. table.concat(Element.alignModes, ", ") .. ")", 2)
    end
end

function Element:__get_alignSelfX(self)
    return self._alignSelfX or self.alignSelf
end

function Element:__set_alignSelfX(self, value)
    if value == nil and self ~= Element then
        self._alignSelfX = nil
        return
    end
    if Element.alignModes:find(value) then
        self._alignSelfX = value
    else
        error("Attempted to set alignSelfX to an invalid value: " .. tostring(value) .. ", (available values: " .. table.concat(Element.alignModes, ", ") .. ")", 2)
    end
end

function Element:__get_alignSelfY(self)
    return self._alignSelfY or self.alignSelf
end

function Element:__set_alignSelfY(self, value)
    if value == nil and self ~= Element then
        self._alignSelfY = nil
        return
    end
    if Element.alignModes:find(value) then
        self._alignSelfY = value
    else
        error("Attempted to set alignSelfY to an invalid value: " .. tostring(value) .. ", (available values: " .. table.concat(Element.alignModes, ", ") .. ")", 2)
    end
end

function Element:__get_spacing(self)
    if type(self._spacing) == "function" then
        return self:_spacing()
    end
    return self._spacing
end

function Element:__set_spacing(self, value)
    if value == nil and self ~= Element then
        self._spacing = nil
        return
    end
    if type(value) == "number" or type(value) == "function" then
        self._spacing = value
    else
        error("Attempted to set spacing to an invalid value: " .. tostring(value) .. " (" .. type(value) .. ")", 2)
    end
    self.dirty = true
end

function Element:__get_padding(self)
    if type(self._padding) == "function" then
        return self:_padding()
    end
    return self._padding
end

function Element:__set_padding(self, value)
    if value == nil and self ~= Element then
        self._padding = nil
        return
    end
    if type(value) == "number" or type(value) == "function" then
        self._padding = value
    else
        error("Attempted to set padding to an invalid value: " .. tostring(value) .. " (" .. type(value) .. ")", 2)
    end
    self.dirty = true
end

function Element:__get_paddingX(self)
    if type(self._paddingX) == "function" then
        return self:_paddingX()
    end
    return self._paddingX or self.padding
end

function Element:__set_paddingX(self, value)
    if value == nil and self ~= Element then
        self._paddingX = nil
        return
    end
    if type(value) == "number" or type(value) == "function" then
        self._paddingX = value
    else
        error("Attempted to set paddingX to an invalid value: " .. tostring(value) .. " (" .. type(value) .. ")", 2)
    end
    self.dirty = true
end

function Element:__get_paddingY(self)
    if type(self._paddingY) == "function" then
        return self:_paddingY()
    end
    return self._paddingY or self.padding
end

function Element:__set_paddingY(self, value)
    if value == nil and self ~= Element then
        self._paddingY = nil
        return
    end
    if type(value) == "number" or type(value) == "function" then
        self._paddingY = value
    else
        error("Attempted to set paddingY to an invalid value: " .. tostring(value) .. " (" .. type(value) .. ")", 2)
    end
    self.dirty = true
end

function Element:__get_paddingL(self)
    if type(self._paddingL) == "function" then
        return self:_paddingL()
    end
    return self._paddingL or self.paddingX
end

function Element:__set_paddingL(self, value)
    if value == nil and self ~= Element then
        self._paddingL = nil
        return
    end
    if type(value) == "number" or type(value) == "function" then
        self._paddingL = value
    else
        error("Attempted to set paddingL to an invalid value: " .. tostring(value) .. " (" .. type(value) .. ")", 2)
    end
    self.dirty = true
end

function Element:__get_paddingT(self)
    if type(self._paddingT) == "function" then
        return self:_paddingT()
    end
    return self._paddingT or self.paddingY
end

function Element:__set_paddingT(self, value)
    if value == nil and self ~= Element then
        self._paddingT = nil
        return
    end
    if type(value) == "number" or type(value) == "function" then
        self._paddingT = value
    else
        error("Attempted to set paddingT to an invalid value: " .. tostring(value) .. " (" .. type(value) .. ")", 2)
    end
    self.dirty = true
end

function Element:__get_paddingR(self)
    if type(self._paddingR) == "function" then
        return self:_paddingR()
    end
    return self._paddingR or self.paddingX
end

function Element:__set_paddingR(self, value)
    if value == nil and self ~= Element then
        self._paddingR = nil
        return
    end
    if type(value) == "number" or type(value) == "function" then
        self._paddingR = value
    else
        error("Attempted to set paddingR to an invalid value: " .. tostring(value) .. " (" .. type(value) .. ")", 2)
    end
    self.dirty = true
end

function Element:__get_paddingB(self)
    if type(self._paddingB) == "function" then
        return self:_paddingB()
    end
    return self._paddingB or self.paddingY
end

function Element:__set_paddingB(self, value)
    if value == nil and self ~= Element then
        self._paddingB = nil
        return
    end
    if type(value) == "number" or type(value) == "function" then
        self._paddingB = value
    else
        error("Attempted to set paddingB to an invalid value: " .. tostring(value) .. " (" .. type(value) .. ")", 2)
    end
    self.dirty = true
end

function Element:__get_margin(self)
    if type(self._margin) == "function" then
        return self:_margin()
    end
    return self._margin
end

function Element:__set_margin(self, value)
    if value == nil and self ~= Element then
        self._margin = nil
        return
    end
    if type(value) == "number" or type(value) == "function" then
        self._margin = value
    else
        error("Attempted to set margin to an invalid value: " .. tostring(value) .. " (" .. type(value) .. ")", 2)
    end
    self.dirty = true
end

function Element:__get_marginX(self)
    if type(self._marginX) == "function" then
        return self:_marginX()
    end
    return self._marginX or self.margin
end

function Element:__set_marginX(self, value)
    if value == nil and self ~= Element then
        self._marginX = nil
        return
    end
    if type(value) == "number" or type(value) == "function" then
        self._marginX = value
    else
        error("Attempted to set marginX to an invalid value: " .. tostring(value) .. " (" .. type(value) .. ")", 2)
    end
    self.dirty = true
end

function Element:__get_marginY(self)
    if type(self._marginY) == "function" then
        return self:_marginY()
    end
    return self._marginY or self.margin
end

function Element:__set_marginY(self, value)
    if value == nil and self ~= Element then
        self._marginY = nil
        return
    end
    if type(value) == "number" or type(value) == "function" then
        self._marginY = value
    else
        error("Attempted to set marginY to an invalid value: " .. tostring(value) .. " (" .. type(value) .. ")", 2)
    end
    self.dirty = true
end

function Element:__get_marginL(self)
    if type(self._marginL) == "function" then
        return self:_marginL()
    end
    return self._marginL or self.marginX
end

function Element:__set_marginL(self, value)
    if value == nil and self ~= Element then
        self._marginL = nil
        return
    end
    if type(value) == "number" or type(value) == "function" then
        self._marginL = value
    else
        error("Attempted to set marginL to an invalid value: " .. tostring(value) .. " (" .. type(value) .. ")", 2)
    end
    self.dirty = true
end

function Element:__get_marginT(self)
    if type(self._marginT) == "function" then
        return self:_marginT()
    end
    return self._marginT or self.marginY
end

function Element:__set_marginT(self, value)
    if value == nil and self ~= Element then
        self._marginT = nil
        return
    end
    if type(value) == "number" or type(value) == "function" then
        self._marginT = value
    else
        error("Attempted to set marginT to an invalid value: " .. tostring(value) .. " (" .. type(value) .. ")", 2)
    end
    self.dirty = true
end

function Element:__get_marginR(self)
    if type(self._marginR) == "function" then
        return self:_marginR()
    end
    return self._marginR or self.marginX
end

function Element:__set_marginR(self, value)
    if value == nil and self ~= Element then
        self._marginR = nil
        return
    end
    if type(value) == "number" or type(value) == "function" then
        self._marginR = value
    else
        error("Attempted to set marginR to an invalid value: " .. tostring(value) .. " (" .. type(value) .. ")", 2)
    end
    self.dirty = true
end

function Element:__get_marginB(self)
    if type(self._marginB) == "function" then
        return self:_marginB()
    end
    return self._marginB or self.marginY
end

function Element:__set_marginB(self, value)
    if value == nil and self ~= Element then
        self._marginB = nil
        return
    end
    if type(value) == "number" or type(value) == "function" then
        self._marginB = value
    else
        error("Attempted to set marginB to an invalid value: " .. tostring(value) .. " (" .. type(value) .. ")", 2)
    end
    self.dirty = true
end

function Element:__get_minWidth(self)
    if type(self._minWidth) == "function" then
        return self:_minWidth() or 0
    end
    return self._minWidth or 0
end

function Element:__set_minWidth(self, value)
    if type(value) == "function" or type(value) == "number" then
        self._minWidth = value
    else
        error("Attempted to set minWidth to an invalid value: " .. tostring(value) .. " (" .. type(value) .. ")", 2)
    end
    self.dirty = true
end

function Element:__get_minHeight(self)
    if type(self._minHeight) == "function" then
        return self:_minHeight() or 0
    end
    return self._minHeight or 0
end

function Element:__set_minHeight(self, value)
    if type(value) == "function" or type(value) == "number" then
        self._minHeight = value
    else
        error("Attempted to set minHeight to an invalid value: " .. tostring(value) .. " (" .. type(value) .. ")", 2)
    end
    self.dirty = true
end

function Element:__get_maxWidth(self)
    if type(self._maxWidth) == "function" then
        return self:_maxWidth() or math.huge
    end
    return self._maxWidth or math.huge
end

function Element:__set_maxWidth(self, value)
    if type(value) == "function" or type(value) == "number" then
        self._maxWidth = value
    else
        error("Attempted to set maxWidth to an invalid value: " .. tostring(value) .. " (" .. type(value) .. ")", 2)
    end
    self.dirty = true
end

function Element:__get_maxHeight(self)
    if type(self._maxHeight) == "function" then
        return self:_maxHeight() or math.huge
    end
    return self._maxHeight or math.huge
end

function Element:__set_maxHeight(self, value)
    if type(value) == "function" or type(value) == "number" then
        self._maxHeight = value
    else
        error("Attempted to set maxHeight to an invalid value: " .. tostring(value) .. " (" .. type(value) .. ")", 2)
    end
    self.dirty = true
end

function Element:__get_width(self)
    if type(self._width) == "function" then
        return self:_width() and math.max(self.minWidth, math.min(self.maxWidth, self:_width())) or nil
    end
    return self._width and math.max(self.minWidth, math.min(self.maxWidth, self._width)) or nil
end

function Element:__set_width(self, value)
    if type(value) == "function" or type(value) == "number" then
        self._width = value
    else
        error("Attempted to set width to an invalid value: " .. tostring(value) .. " (" .. type(value) .. ")", 2)
    end
    self.dirty = true
end

function Element:__get_height(self)
    if type(self._height) == "function" then
        return self:_height() and math.max(self.minHeight, math.min(self.maxHeight, self:_height())) or nil
    end
    return self._height and math.max(self.minHeight, math.min(self.maxHeight, self._height)) or nil
end

function Element:__set_height(self, value)
    if type(value) == "function" or type(value) == "number" then
        self._height = value
    else
        error("Attempted to set height to an invalid value: " .. tostring(value) .. " (" .. type(value) .. ")", 2)
    end
    self.dirty = true
end

function Element:__get_stretchWeight(self)
    if type(self._stretchWeight) == "function" then
        return self:_stretchWeight()
    end
    return self._stretchWeight or 1
end

function Element:__set_stretchWeight(self, value)
    if type(value) == "function" or type(value) == "number" and value > 0 then
        self._stretchWeight = value
    else
        error("Attempted to set stretchWeight to an invalid value: " .. tostring(value) .. " (" .. type(value) .. ")", 2)
    end
    if self.inLayout and Element:isClassOf(self.parent) then
        self.parent.dirty = true
    end
end

function Element:__get_rawContentWidth(self)
    if self.direction == "horizontal" then
        local w = 0
        for i, elem in self._elements:iterate() do
            w = w + elem.w
        end
        return w
    else
        local w = 0
        for i, elem in self._elements:iterate() do
            w = math.max(w, elem.w)
        end
        return w
    end
end

function Element:__get_rawContentHeight(self)
    if self.direction == "vertical" then
        local h = 0
        for i, elem in self._elements:iterate() do
            h = h + elem.h
        end
        return h
    else
        local h = 0
        for i, elem in self._elements:iterate() do
            h = math.max(h, elem.h)
        end
        return h
    end
end

function Element:__get_contentWidth(self)
    if self.direction == "horizontal" then
        local elements = self._elements:filtered(function(elem) return elem.inLayout end)
        local w = 0
        for i, elem in elements:iterate() do
            if i == 1 then
                w = w + math.max(self.paddingL, elem.marginL)
            end
            w = w + elem.w
            if i < elements.length then
                w = w + math.max(self.spacing, elem.marginR, elements[i + 1].marginL)
            else
                w = w + math.max(self.paddingR, elem.marginR)
            end
        end
        return w
    else
        local w = 0
        for i, elem in self._elements:iterate() do
            w = math.max(w, elem.w + math.max(self.paddingL, elem.marginL) + math.max(self.paddingR, elem.marginR))
        end
        return w
    end
end

function Element:__get_contentHeight(self)
    if self.direction == "vertical" then
        local elements = self._elements:filtered(function(elem) return elem.inLayout end)
        local h = 0
        for i, elem in elements:iterate() do
            if i == 1 then
                h = h + math.max(self.paddingT, elem.marginT)
            end
            h = h + elem.h
            if i < elements.length then
                h = h + math.max(self.spacing, elem.marginB, elements[i + 1].marginT)
            else
                h = h + math.max(self.paddingB, elem.marginB)
            end
        end
        return h
    else
        local h = 0
        for i, elem in self._elements:iterate() do
            h = math.max(h, elem.h + math.max(self.paddingT, elem.marginT) + math.max(self.paddingB, elem.marginB))
        end
        return h
    end
end

function Element:__get_x(self)
    local x = Element:isClassOf(self.parent) and self.parent.x + self.parent.scrollX or love.graphics.getWidth() / 2
    local w = Element:isClassOf(self.parent) and self.parent.w or love.graphics.getWidth()
    if self._x then
        return x + self._x
    else
        local l = x - w/2 + self.marginL
        local r = x + w/2 - self.marginR
        if self.alignSelfX == "start" then
            return l + self.w/2
        elseif self.alignSelfX == "end" then
            return r - self.w/2
        else
            return (l + r) / 2
        end
    end
end

function Element:__get_y(self)
    local y = Element:isClassOf(self.parent) and self.parent.y + self.parent.scrollY or love.graphics.getHeight() / 2
    local h = Element:isClassOf(self.parent) and self.parent.h or love.graphics.getHeight()
    if self._y then
        return y + self._y
    else
        local t = y - h/2 + self.marginT
        local b = y + h/2 - self.marginB
        if self.alignSelfY == "start" then
            return t + self.h/2
        elseif self.alignSelfY == "end" then
            return b - self.h/2
        else
            return (t + b) / 2
        end
    end
end

function Element:__get_w(self)
    local w = Element:isClassOf(self.parent) and self.parent.w or love.graphics.getWidth()
    return self._w or math.max(self.minWidth, math.min(self.maxWidth, self.width or self.alignSelfX == "stretch" and w - math.max(self.paddingL, self.marginL) - math.max(self.paddingR, self.marginR) or self.contentWidth))
end

function Element:__get_h(self)
    local h = Element:isClassOf(self.parent) and self.parent.h or love.graphics.getHeight()
    return self._h or math.max(self.minHeight, math.min(self.maxHeight, self.height or self.alignSelfY == "stretch" and h - math.max(self.paddingT, self.marginT) - math.max(self.paddingB, self.marginB) or self.contentHeight))
end

function Element:__get_l(self)
    return self.x - self.w/2
end

function Element:__get_t(self)
    return self.y - self.h/2
end

function Element:__get_r(self)
    return self.x + self.w/2
end

function Element:__get_b(self)
    return self.y + self.h/2
end

function Element:recalculate()
    if not self then -- Element.recalculate() handles all dirty elements
        while next(Element._dirty) do
            next(Element._dirty):recalculate()
        end
        return
    end
    if self.inLayout and Element:isClassOf(self.parent) then
        self.parent:recalculate()
    end
    for i, elem in self._elements:iterate() do
        elem._x, elem._y, elem._w, elem._h = nil
    end
    local elements = self._elements:filtered(function(elem) return elem.inLayout end)
    if elements.length == 0 then
        self.scrollX, self.scrollY = 0, 0
        return
    end
    -- horizontal (x, w, l, r)
    if self.direction == "horizontal" then
        local minWidth, maxWidth, stretchWeight = 0, 0, 0
        local rawContentWidth, contentWidth, availableWidth = self.rawContentWidth, self.contentWidth, self.w
        local totalSpacing = contentWidth - rawContentWidth
        for i, elem in elements:iterate() do
            local s = i < elements.length and math.max(elem.marginR, elem.next.marginL, self.spacing) or elem.marginR
            if i == 1 then s = s + elem.marginL end
            minWidth       = minWidth       + elem.minWidth
            maxWidth       = maxWidth       + elem.maxWidth
            stretchWeight  = stretchWeight  + elem.stretchWeight
        end
        if self.justify == "stretch" and minWidth + totalSpacing < availableWidth and maxWidth + totalSpacing > availableWidth then
            local widths, flexible = {}, array()
            local fixedSize = 0
            local flexibleWeight = 0
            for i, elem in elements:iterate() do
                local intendedSize = availableWidth / stretchWeight * elem.stretchWeight
                if elem.width then
                    widths[elem] = elem.width
                    fixedSize = fixedSize + elem.width
                elseif intendedSize < elem.minWidth then
                    widths[elem] = elem.minWidth
                    fixedSize = fixedSize + elem.minWidth
                elseif intendedSize > elem.maxWidth then
                    widths[elem] = elem.maxWidth
                    fixedSize = fixedSize + elem.maxWidth
                else
                    flexible:append(elem)
                    flexibleWeight = flexibleWeight + elem.stretchWeight
                end
            end
            if flexible.length > 0 then
                local flexibleSize = availableWidth - totalSpacing - fixedSize
                for i, elem in flexible:iterate() do
                    widths[elem] = flexibleSize / flexibleWeight * elem.stretchWeight
                    fixedSize = fixedSize + widths[elem]
                end
            end
            local p = 0
            for i, elem in elements:iterate() do
                p = p + i > 1 and math.max(elem.marginL, elem.previous.marginR, self.spacing) or math.max(elem.marginL, self.paddingL)
                elem._w = widths[elem]
                elem._x = p + elem._w / 2 - self.w / 2
                p = p + elem._w
            end
        elseif self.justify == "space" and elements.length > 1 and contentWidth < availableWidth then
            local spaces, flexible = {}, array()
            local availableSpace = (availableWidth - rawContentWidth
                - math.max(self.paddingL, elements[ 1].marginL)
                - math.max(self.paddingR, elements[-1].marginR)
            )
            local fixedSpace = 0
            local intendedSpace = availableSpace / (elements.length - 1)
            for i, elem in elements:iterate() do
                if i < elements.length then
                    local s = math.max(elem.marginR, elements[i + 1].marginL, self.spacing)
                    if intendedSpace < s then
                        spaces[i] = s
                        fixedSpace = fixedSpace + s
                    else
                        flexible:append(i)
                    end
                end
            end
            intendedSpace = (availableSpace - fixedSpace) / flexible.length
            for i, s in flexible:iterate() do
                spaces[s] = intendedSpace
            end
            local p = spaces[0]
            for i, elem in elements:iterate() do
                elem._w = elem.w
                elem._x = p + elem._w / 2 - availableWidth / 2
                p = p + elem._w
                if i < elements.length then
                    p = p + spaces[i]
                end
            end
        elseif (self.justify == "even" or self.justify == "space" and elements.length == 1 or self.justify == "stretch" and minWidth + totalSpacing < availableWidth) and contentWidth < availableWidth then
            local spaces, flexible = {}, array()
            local availableSpace = availableWidth - rawContentWidth
            local fixedSpace = 0
            local intendedSpace = availableSpace / (elements.length + 1)
            for i, elem in elements:iterate() do
                local s = i > 1 and math.max(elem.marginL, elements[i - 1].marginR, self.spacing) or math.max(elem.marginL, self.paddingL)
                if intendedSpace < s then
                    spaces[i] = s
                    fixedSpace = fixedSpace + s
                else
                    flexible:append(i)
                end
                if i == elements.length then
                    local rs = math.max(elem.marginR, self.paddingR)
                    if intendedSpace < rs then
                        spaces[0] = rs
                        fixedSpace = fixedSpace + rs
                    else
                        flexible:append(0)
                    end
                end
            end
            intendedSpace = (availableSpace - fixedSpace) / flexible.length
            for i, s in flexible:iterate() do
                spaces[s] = intendedSpace
            end
            local p = 0
            for i, elem in elements:iterate() do
                p = p + spaces[i]
                elem._w = elem.w
                elem._x = p + elem._w / 2 - availableWidth / 2
                p = p + elem._w
            end
        else
            local p = self.justify == "center" and availableWidth / 2 - contentWidth / 2 or self.justify == "end" and availableWidth - contentWidth or 0
            for i, elem in elements:iterate() do
                p = p + i > 1 and math.max(elem.marginL, elements[i - 1].marginR, self.spacing) or math.max(elem.marginL, self.paddingL)
                elem._w = elem.w
                elem._x = p + elem._w / 2 - availableWidth / 2
                p = p + elem._w
            end
        end
    elseif self.direction == "vertical" then
        local minHeight, maxHeight, stretchWeight = 0, 0, 0
        local rawContentHeight, contentHeight, availableHeight = self.rawContentHeight, self.contentHeight, self.h
        local totalSpacing = contentHeight - rawContentHeight
        for i, elem in elements:iterate() do
            local s = i < elements.length and math.max(elem.marginB, elem.next.marginT, self.spacing) or elem.marginB
            if i == 1 then s = s + elem.marginT end
            minHeight       = minHeight       + elem.minHeight
            maxHeight       = maxHeight       + elem.maxHeight
            stretchWeight   = stretchWeight   + elem.stretchWeight
        end
        if self.justify == "stretch" and minHeight + totalSpacing < availableHeight and maxHeight + totalSpacing > availableHeight then
            local heights, flexible = {}, array()
            local fixedSize = 0
            local flexibleWeight = 0
            for i, elem in elements:iterate() do
                local intendedSize = availableHeight / stretchWeight * elem.stretchWeight
                if elem.height then
                    heights[elem] = elem.height
                    fixedSize = fixedSize + elem.height
                elseif intendedSize < elem.minHeight then
                    heights[elem] = elem.minHeight
                    fixedSize = fixedSize + elem.minHeight
                elseif intendedSize > elem.maxHeight then
                    heights[elem] = elem.maxHeight
                    fixedSize = fixedSize + elem.maxHeight
                else
                    flexible:append(elem)
                    flexibleWeight = flexibleWeight + elem.stretchWeight
                end
            end
            if flexible.length > 0 then
                local flexibleSize = availableHeight - totalSpacing - fixedSize
                for i, elem in flexible:iterate() do
                    heights[elem] = flexibleSize / flexibleWeight * elem.stretchWeight
                    fixedSize = fixedSize + heights[elem]
                end
            end
            local p = 0
            for i, elem in elements:iterate() do
                p = p + i > 1 and math.max(elem.marginT, elem.previous.marginB, self.spacing) or math.max(elem.marginT, self.paddingT)
                elem._h = heights[elem]
                elem._y = p + elem._h / 2 - availableHeight / 2
                p = p + elem._h
            end
        elseif self.justify == "space" and elements.length > 1 and contentHeight < availableHeight then
            local spaces, flexible = {}, array()
            local fixedSize = 0
            local intendedSpace = (availableHeight - totalSpacing) / (elements.length - 1)
            for i, elem in elements:iterate() do
                if i < elements.length then
                    if intendedSpace < elem.marginB then
                        spaces[i] = elem.marginB
                        fixedSize = fixedSize + elem.marginB
                    else
                        flexible:append(i)
                    end
                end
            end
            intendedSpace = (availableHeight - totalSpacing - fixedSize) / flexible.length
            for i, s in flexible:iterate() do
                spaces[s] = intendedSpace
            end
            local p = 0
            for i, elem in elements:iterate() do
                elem._h = elem.height or math.max(elem.minHeight, math.min(elem.maxHeight, elem.contentHeight))
                elem._y = p + elem._h / 2 - availableHeight / 2
                p = p + elem._h
                if i < elements.length then
                    p = p + spaces[i]
                end
            end
        elseif (self.justify == "even" or self.justify == "space" and elements.length == 1 or self.justify == "stretch" and minHeight < availableHeight) and contentHeight < availableHeight then
            local spaces, flexible = {}, array()
            local fixedSize = 0
            local intendedSpace = (availableHeight - totalSpacing) / (elements.length + 1)
            for i, elem in elements:iterate() do
                if intendedSpace < elem.marginT then
                    spaces[i] = elem.marginT
                    fixedSize = fixedSize + elem.marginT
                else
                    flexible:append(i)
                end
                if i == elements.length then
                    if intendedSpace < elem.marginB then
                        spaces[0] = elem.marginB
                        fixedSize = fixedSize + elem.marginB
                    else
                        flexible:append(0)
                    end
                end
            end
            intendedSpace = (availableHeight - totalSpacing - fixedSize) / flexible.length
            for i, s in flexible:iterate() do
                spaces[s] = intendedSpace
            end
            local p = 0
            for i, elem in elements:iterate() do
                p = p + spaces[i]
                elem._h = elem.height or math.max(elem.minHeight, math.min(elem.maxHeight, elem.contentHeight))
                elem._y = p + elem._h / 2 - availableHeight / 2
                p = p + elem._h
            end
        else
            local p = self.justify == "center" and availableHeight / 2 - contentHeight / 2 or self.justify == "end" and availableHeight - contentHeight or 0
            for i, elem in elements:iterate() do
                p = p + i > 1 and math.max(elem.marginT, elem.previous.marginB, self.spacing) or elem.marginT
                elem._h = elem.height or math.max(elem.minHeight, math.min(elem.maxHeight, elem.contentHeight))
                elem._y = p + elem._h / 2 - availableHeight / 2
                p = p + elem._h
            end
        end
    end
    -- x scroll
    if contentWidth > availableWidth then
        local minScrollX = (self.direction == "horizontal" and self.justify == "end"    or self.align == "end"   )
                            and availableWidth - contentWidth
                        or (self.direction == "horizontal" and self.justify == "center" or self.align == "center")
                            and availableWidth / 2 - contentWidth / 2
                        or 0
        local maxScrollX = (self.direction == "horizontal" and self.justify == "end"    or self.align == "end"   )
                            and 0
                        or (self.direction == "horizontal" and self.justify == "center" or self.align == "center")
                            and contentWidth / 2 - availableWidth / 2
                        or contentWidth - availableWidth
        self.scrollX = math.max(minScrollX, math.min(maxScrollX, self.scrollX))
    else
        self.scrollX = 0
    end
    -- y scroll
    if contentHeight > availableHeight then
        local minScrollY = (self.direction == "vertical" and self.justify == "end"    or self.align == "end"   )
                            and  availableHeight - contentHeight
                        or (self.direction == "vertical" and self.justify == "center" or self.align == "center")
                            and availableHeight / 2 - contentHeight / 2
                        or 0
        local maxScrollY = (self.direction == "vertical" and self.justify == "end"    or self.align == "end"   )
                            and 0
                        or (self.direction == "vertical" and self.justify == "center" or self.align == "center")
                            and contentHeight / 2 - availableHeight / 2
                        or contentHeight - availableHeight
        self.scrollY = math.max(minScrollY, math.min(maxScrollY, self.scrollY))
    else
        self.scrollY = 0
    end
    self.dirty = false
end

function Element:check(x, y)
    if not self.clip then
        for i, elem in self._elements:iterate() do
            if elem:check(x, y) then
                return true
            end
        end
    end
    return x > self.l and y > self.t and x < self.r and y < self.b
end

function Element:predraw()
    if self.clip then
        love.graphics.intersectScissor(self.l, self.t, self.w, self.h)
    end
end

Element.inLayout = true
Element.direction = "vertical"
Element.justify = "start"
Element.align = "start"

Element.spacing = 0
Element.padding = 0
Element.margin = 0

Element.scrollSpeed = 5

return Element