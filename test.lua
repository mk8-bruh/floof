-- Test the callback system
local floof = require("init")
local Object = require("object")

print("=== Testing Callback System ===")

-- Create a test class
local TestButton = floof("TestButton", Object)

-- Test 1: Setting callbacks on class
TestButton.pressed = function(self, x, y, id)
    print("TestButton class pressed callback called!")
    return true
end

TestButton.moved = true  -- Should create function() return true end

-- Test 2: Setting callbacks on instance
local button = TestButton()
button.released = function(self, x, y, id)
    print("Button instance released callback called!")
    return false
end

button.update = function(self, dt)
    print("Button instance update callback called!")
end

-- Test 3: Test callback execution
print("\n--- Testing callback execution ---")
button:pressed(100, 100, 1)  -- Should call class callback
button:released(100, 100, 1) -- Should call instance callback
button:update(0.016)         -- Should call instance callback

-- Test 4: Test boolean callback
print("\n--- Testing boolean callback ---")
local result = button:moved(100, 100, 0, 0, 1)
print("moved callback returned:", result)

print("\n=== Callback system test completed! ===")
