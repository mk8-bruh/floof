PATH = (...):match("^(.+%.).-$") or ""

return setmetatable({}, {
    __index = {
        class = require(PATH .. "class"),
        object = require(PATH .. "object"),
        array = require(PATH .. "array")
    },
    __newindex = function() end,
    __metatable = {},
    __tostring = function() return "<FLOOF main module>" end,
    __call = function(self)
        self.object.setup()
    end
})