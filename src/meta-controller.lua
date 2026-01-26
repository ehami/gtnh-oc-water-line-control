local stateMachineLib = require("lib.state-machine-lib")
local componentDiscoverLib = require("lib.component-discover-lib")
local gtSensorParserLib = require("lib.gt-sensor-parser")

local metaController = {}

---Create new MetaController object
---@param machineType string
function metaController:new(machineType)

  ---@class MetaController
  local obj = {}

  obj.controllerProxy = nil

  obj.stateMachine = stateMachineLib:new()
  obj.gtSensorParser = nil

  ---Init Controller
  function obj:init()
    self:findMachineProxy()
  end

  ---Find controller proxy
  function obj:findMachineProxy()
    self.controllerProxy = componentDiscoverLib.discoverGtMachine(machineType)

    if self.controllerProxy == nil then
      error(machineType.." not found")
    end

    self.gtSensorParser = gtSensorParserLib:new(self.controllerProxy)
  end

  ---Loop
  function obj:loop()

    if self.gtSensorParser == nil or self.controllerProxy == nil then
      return
    end
    self.gtSensorParser:getInformation()
    self.stateMachine:update()
  end

  ---Get current state
  ---@return string
  function obj:getState()
    if self.controllerProxy == nil then
      return "Error"
    end

    if self.controllerProxy.isWorkAllowed() == false then
      return "Disabled"
    end

    if self.controllerProxy.hasWork() == false then
      return "Waiting"
    end

    return self.stateMachine.currentState and self.stateMachine.currentState.name or "nil"
  end

  ---Get current success chance
  ---@return number
  function obj:getSuccess()
    if self.gtSensorParser == nil then
      return -1
    end

    local successChange = self.gtSensorParser:getNumber(2, "Success chance:")

    if successChange == nil then
      successChange = 0
    end

    return successChange
  end

  setmetatable(obj, self)
  self.__index = self
  return obj
end

return metaController