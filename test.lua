local class = require("class")

print("=== Testing New Getter/Setter System ===")

-- Test 1: Method-based syntax
local TestClass = class("TestClass")

TestClass:getter("value", function(self) 
    print("TestClass getter called")
    return self._value or 0 
end)

TestClass:setter("value", function(self, v) 
    print("TestClass setter called")
    self._value = v 
end)

function TestClass:init()
    self._value = 10
end

-- Test 2: Decorator syntax (@get_, @set_)
local DecoratorClass = class("DecoratorClass")

DecoratorClass["@get_count"] = function(self)
    print("DecoratorClass getter called")
    return self._count or 0
end

DecoratorClass["@set_count"] = function(self, v)
    print("DecoratorClass setter called")
    self._count = v * 2  -- Store double the value
end

function DecoratorClass:init()
    self._count = 5
end

-- Test 3: Combined syntax
local CombinedClass = class("CombinedClass")

CombinedClass:property("name", 
    function(self) return self._name or "unnamed" end,
    function(self, v) self._name = v end
)

CombinedClass["@get_age"] = function(self) return self._age or 0 end
CombinedClass:setter("age", function(self, v) self._age = v end)

function CombinedClass:init()
    self._name = "test"
    self._age = 25
end

-- Test 4: Inheritance with getters/setters
local BaseClass = class("BaseClass")

BaseClass:getter("data", function(self) 
    print("BaseClass getter called")
    return self._data or "base" 
end)

BaseClass:setter("data", function(self, v) 
    print("BaseClass setter called")
    self._data = v 
end)

function BaseClass:init()
    self._data = "base_data"
end

local DerivedClass = class("DerivedClass", BaseClass)

DerivedClass:getter("data", function(self) 
    print("DerivedClass getter called")
    return self._data .. "_derived"  -- Append "_derived"
end)

DerivedClass:setter("data", function(self, v) 
    print("DerivedClass setter called")
    self._data = v:upper()  -- Convert to uppercase
end)

function DerivedClass:init()
    self.super.init(self)
end

-- Test instances
local test1 = TestClass()
local decorator = DecoratorClass()
local combined = CombinedClass()
local base = BaseClass()
local derived = DerivedClass()

print("\n--- Testing Method-based syntax ---")
print("Initial value:", test1.value)
test1.value = 20
print("After setting to 20:", test1.value)

print("\n--- Testing Decorator syntax ---")
print("Initial count:", decorator.count)
decorator.count = 10
print("After setting to 10:", decorator.count)  -- Should be 20 (10 * 2)

print("\n--- Testing Combined syntax ---")
print("Name:", combined.name)
print("Age:", combined.age)
combined.name = "new_name"
combined.age = 30
print("After changes - Name:", combined.name, "Age:", combined.age)

print("\n--- Testing Inheritance ---")
print("Base data:", base.data)
base.data = "hello"
print("Base after setting 'hello':", base.data)

print("Derived data:", derived.data)  -- Should be "base_data_derived"
derived.data = "world"
print("Derived after setting 'world':", derived.data)  -- Should be "WORLD_derived"

print("\n=== All tests completed! ===")