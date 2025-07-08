local _PATH = (...):match("(.-)[^%.]+$")

return {
    object = require(_PATH .. ".object"),
    class = require(_PATH .. ".class"),
    input = require(_PATH .. ".input"),
    hitbox = require(_PATH .. ".hitbox"),
    array = require(_PATH .. ".array")
} 