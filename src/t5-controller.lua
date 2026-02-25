local sides = require("sides")
local event = require("event")

local componentDiscoverLib = require("lib.component-discover-lib")

local Controller = require("src.controller")


---@class T5ControllerConfig
---@field plasmaTransposerAddress string
---@field coolantTransposerAddress string

---@class T5Controller: Controller
local T5Controller = Controller:createChild()

-- Create new T5Controller object
---@param plasmaTransposerAddress string
---@param coolantTransposerAddress string
function T5Controller:_init(plasmaTransposerAddress, coolantTransposerAddress)
  Controller._init(self, "multimachine.purificationunitplasmaheater", "[T5] Extreme Temperature Fluctuation Purification Unit")

  self.plasmaTransposerAddress = plasmaTransposerAddress
  self.coolantTransposerAddress = coolantTransposerAddress

  self.plasmaTransposerProxy = nil
  self.coolantTransposerProxy = nil

  self.transposerLiquids = {}

  self.coolantCount = 2000
  self.plasmaCount = 100
end

---Create new T5Controller object from config
---@param config T5ControllerConfig
---@return T5Controller
function T5Controller:fromConfig(config)
  return T5Controller(config.plasmaTransposerAddress, config.coolantTransposerAddress)
end

function T5Controller:gtInit()
  Controller.gtInit(self)

  self.plasmaTransposerProxy = componentDiscoverLib.discoverProxy(self.plasmaTransposerAddress, "[T5] Plasma Transposer", "transposer")
  self.coolantTransposerProxy = componentDiscoverLib.discoverProxy(self.coolantTransposerAddress, "[T5] Coolant Transposer", "transposer")

  self:findTransposerFluid(self.plasmaTransposerProxy, "plasma.helium")
  self:findTransposerFluid(self.coolantTransposerProxy, "supercoolant")
end

function T5Controller:stateMachineInit()
  self.stateMachine.states.idle = self.stateMachine:createState("Idle")
  self.stateMachine.states.idle.init = function ()
    local temperature = self.gtSensorParser:getNumber(4, "Current temperature:")

    if self.controllerProxy.hasWork() and temperature ~= nil and temperature ~= 0 then
      self.stateMachine:setState(self.stateMachine.states.waitEnd)
    end
  end
  self.stateMachine.states.idle.update = function()
    if self.controllerProxy.getWorkProgress() > 900 then 
      self.stateMachine:setState(self.stateMachine.states.waitEnd)
      return
    end

    if self.controllerProxy.hasWork() then
      self.stateMachine.data.iterations = 0
      self.stateMachine:setState(self.stateMachine.states.heating)
    end
  end

  self.stateMachine.states.heating = self.stateMachine:createState("Heating")
  self.stateMachine.states.heating.init = function ()
    if self.stateMachine.data.iterations >= 2 then
      self.stateMachine:setState(self.stateMachine.states.waitEnd)
      return
    end

    local _, result = self.plasmaTransposerProxy.transferFluid(
      self.transposerLiquids["plasma.helium"].side,
      sides.up,
      self.plasmaCount,
      self.transposerLiquids["plasma.helium"].tank)

    if result ~= self.plasmaCount then
      self.controllerProxy.setWorkAllowed(false)
      event.push("log_warning", "[T5] Not enough Helium Plasma for craft")
    end
  end
  self.stateMachine.states.heating.update = function()
    local temperature = self.gtSensorParser:getNumber(4, "Current temperature:")

    if self.controllerProxy.hasWork() == false then
      self.stateMachine:setState(self.stateMachine.states.idle)
    end

    if temperature >= 10000 then
      self.stateMachine:setState(self.stateMachine.states.cooling)
    end
  end

  self.stateMachine.states.cooling = self.stateMachine:createState("Cooling")
  self.stateMachine.states.cooling.init = function ()
    local _, result = self.coolantTransposerProxy.transferFluid(
      self.transposerLiquids["supercoolant"].side,
      sides.up,
      self.coolantCount,
      self.transposerLiquids["supercoolant"].tank)

    if result ~= self.coolantCount then
      self.controllerProxy.setWorkAllowed(false)
      event.push("log_warning", "[T5] Not enough Super Coolant for craft")
    end
  end
  self.stateMachine.states.cooling.update = function()
    local temperature = self.gtSensorParser:getNumber(4, "Current temperature:")

    if self.controllerProxy.hasWork() == false then
      self.stateMachine:setState(self.stateMachine.states.idle)
    end

    if temperature <= 0 then
      self.stateMachine:setState(self.stateMachine.states.heating)
      self.stateMachine.data.iterations = self.stateMachine.data.iterations + 1
    end
  end

  self.stateMachine.states.waitEnd = self.stateMachine:createState("Wait End")

  event.listen("cycle_end", function ()
    if self.stateMachine.currentState == self.stateMachine.states.waitEnd then
      self.stateMachine:setState(self.stateMachine.states.idle)
    end
  end)

  self.stateMachine:setState(self.stateMachine.states.idle)
end

  ---Find side of transposer with fluid
  ---@param proxy transposer
  ---@param fluidName string
  function T5Controller:findTransposerFluid(proxy, fluidName)
    local result, skipped = componentDiscoverLib.discoverTransposerFluidStorage(proxy, {fluidName}, {sides.up})

    if #skipped ~= 0 then
      error("[T5] Can't find liquid: "..table.concat(skipped, ", "))
    end

    for key, value in pairs(result) do
      self.transposerLiquids[key] = value
    end
  end

return T5Controller