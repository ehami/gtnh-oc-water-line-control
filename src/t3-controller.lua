local sides = require("sides")
local event = require("event")

local componentDiscoverLib = require("lib.component-discover-lib")

local Controller = require("src.controller")


---@class T3ControllerConfig
---@field transposerAddress string

---@class T3Controller: Controller
local T3Controller = Controller:createChild()

---@param transposerAddress string
function T3Controller:_init(transposerAddress)
  Controller._init(self, "multimachine.purificationunitflocculator", "[T3] Flocculation Purification Unit") -- call the base class constructor

  self.transposerAddress = transposerAddress

  self.transposerProxy = nil
  self.transposerLiquids = {}
  self.requiredCount = 900000;
end

-- Create new T3Controller object from config
---@param config T3ControllerConfig
---@return T3Controller
function T3Controller:fromConfig(config)
  return T3Controller(config.transposerAddress)
end

function T3Controller:gtInit()
  Controller.gtInit(self)

  self.transposerProxy = componentDiscoverLib.discoverProxy(self.transposerAddress, "[T3] Transposer", "transposer")
  self:findTransposerFluid(self.transposerProxy, "polyaluminiumchloride")
end

function T3Controller:stateMachineInit()

  self.stateMachine.states.idle = self.stateMachine:createState("Idle")
  self.stateMachine.states.idle.update = function()
    if self.controllerProxy.hasWork() then
      self.stateMachine:setState(self.stateMachine.states.work)
    end
  end

  self.stateMachine.states.work = self.stateMachine:createState("Work")
  self.stateMachine.states.work.init = function()
    local currentCount = self.gtSensorParser:getNumber(4, "Polyaluminium Chloride consumed this cycle: §c")

    if currentCount ~= nil and currentCount >= self.requiredCount then
      self.stateMachine:setState(self.stateMachine.states.waitEnd)
      return
    end

    local fluidInTank = self.transposerProxy.getFluidInTank(
      self.transposerLiquids["polyaluminiumchloride"].side,
      self.transposerLiquids["polyaluminiumchloride"].tank
    )

    local countToAdd = self.requiredCount

    if fluidInTank.amount < self.requiredCount then
      self.controllerProxy.setWorkAllowed(false)
      event.push("log_warning", "[T3] Not enough Polyaluminium Chloride for craft")

      countToAdd = fluidInTank.amount - (fluidInTank.amount % 100000)
    end

    local _, result = self.transposerProxy.transferFluid(
      self.transposerLiquids["polyaluminiumchloride"].side,
      sides.up,
      countToAdd,
      self.transposerLiquids["polyaluminiumchloride"].tank
    )

    if result ~= countToAdd then
      event.push("log_warning", "[T3] Fluid transfer error")
    end

    self.stateMachine:setState(self.stateMachine.states.waitEnd)
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
function T3Controller:findTransposerFluid(proxy, fluidName)
  local result, skipped = componentDiscoverLib.discoverTransposerFluidStorage(proxy, {fluidName}, {sides.up})

  if #skipped ~= 0 then
    error("[T4] Can't find liquid: "..table.concat(skipped, ", "))
  end

  for key, value in pairs(result) do
    self.transposerLiquids[key] = value
  end
end

return T3Controller
