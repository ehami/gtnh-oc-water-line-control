local stateMachineLib = require("lib.state-machine-lib")
local componentDiscoverLib = require("lib.component-discover-lib")
local gtSensorParserLib = require("lib.gt-sensor-parser")
local event = require("event")


--- @class Controller
local Controller = {}
Controller.__index = Controller
Controller.is_a = {[Controller] = true}

setmetatable(Controller, {
  __call = function (cls, ...)
    local self = setmetatable({}, cls)
    self:_init(...)
    return self
  end,
})

--- @param machineType string
--- @param machineFriendlyName string
function Controller:_init(machineType, machineFriendlyName)
  self.machineType = machineType
  self.machineFriendlyName = machineFriendlyName
  self.stateMachine = stateMachineLib:new()
end

function Controller:gtInit()
    self.controllerProxy = componentDiscoverLib.discoverGtMachine(self.machineType)

    if self.controllerProxy == nil then
      error(self.machineType.." not found")
    end

    self.gtSensorParser = gtSensorParserLib:new(self.controllerProxy)

    self.stateMachine.states.idle = self.stateMachine:createState("Idle")
    self.stateMachine.states.work = self.stateMachine:createState("Work")
    self.stateMachine.states.waitEnd = self.stateMachine:createState("Wait End")
    
    self.stateMachine.states.idle.update = function()
      if self.controllerProxy.hasWork() then
        self.stateMachine:setState(self.stateMachine.states.work)
      end
    end

    self.stateMachine.states.work.init = function()
        self.stateMachine:setState(self.stateMachine.states.waitEnd)
    end


    event.listen(
        "cycle_end", 
        function ()
            if self.stateMachine.currentState == self.stateMachine.states.waitEnd then
                self.stateMachine:setState(self.stateMachine.states.idle)
            end
        end
    )

    self.stateMachine:setState(self.stateMachine.states.idle)
end

---Loop
function Controller:loop()
self.gtSensorParser:getInformation()
self.stateMachine:update()
end

-- Get current state
---@return string
function Controller:getState()
    if self.controllerProxy == nil then
        return "Error"
    end

    if self.controllerProxy.isWorkAllowed() == false then
        return "Disabled"
    end

    if self.controllerProxy.hasWork() == false then
        return "Wait cycle"
    end

    return self.stateMachine.currentState and self.stateMachine.currentState.name or "nil"
end

-- Get current success chance
---@return number
function Controller:getSuccess()
    if self.gtSensorParser == nil then
        return -2
    end

    local successChance = self.gtSensorParser:getNumber(2, "Success chance:")

    if successChance == nil then
        successChance = -1
    end

    return successChance
end

-- Enable/Disable Machine
--- @param isEnabled boolean
function Controller:setEnabled(isEnabled)
    self.controllerProxy.setWorkAllowed(isEnabled)
end

-- Based on http://lua-users.org/wiki/ObjectOrientationTutorial
function Controller:createChild()
  -- "cls" is the new class
  local cls, bases = {}, {Controller}
  -- copy base class contents into the new class
  for i, base in ipairs(bases) do
    for k, v in pairs(base) do
      cls[k] = v
    end
  end
  -- set the class's __index, and start filling an "is_a" table that contains this class and all of its bases
  -- so you can do an "instance of" check using my_instance.is_a[MyClass]
  cls.__index, cls.is_a = cls, {[cls] = true}
  for i, base in ipairs(bases) do
    for c in pairs(base.is_a) do
      cls.is_a[c] = true
    end
    cls.is_a[base] = true
  end
  -- the class's __call metamethod
  setmetatable(cls, {__call = function (c, ...)
    local instance = setmetatable({}, c)
    -- run the init method if it's there
    local init = instance._init
    if init then init(instance, ...) end
    return instance
  end})
  -- return the new class table, that's ready to fill with methods
  return cls
end

return Controller