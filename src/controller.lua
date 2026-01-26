local stateMachineLib = require("lib.state-machine-lib")
local componentDiscoverLib = require("lib.component-discover-lib")
local gtSensorParserLib = require("lib.gt-sensor-parser")
local event = require("event")

local Controller = {}
Controller.__index = Controller

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

return Controller