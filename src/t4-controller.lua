
local sides = require("sides")
local event = require("event")

local componentDiscoverLib = require("lib.component-discover-lib")
local gtSensorParserLib = require("lib.gt-sensor-parser")

local Controller = require("src.controller")


---@class T4ControllerConfig
---@field hydrochloricAcidTransposerAddress string
---@field sodiumHydroxideTransposerAddress string

---@class T4Controller: Controller
local T4Controller = Controller:createChild()

---@param hydrochloricAcidTransposerAddress string
---@param sodiumHydroxideTransposerAddress string
function T4Controller:_init(hydrochloricAcidTransposerAddress, sodiumHydroxideTransposerAddress)
  Controller._init(self, "multimachine.purificationunitphadjustment", "[T4] pH Neutralization Purification Unit")

  self.hydrochloricAcidTransposerAddress = hydrochloricAcidTransposerAddress
  self.sodiumHydroxideTransposerAddress = sodiumHydroxideTransposerAddress

  self.hydrochloricAcidTransposerProxy = nil
  self.sodiumHydroxideTransposerProxy = nil

  self.transposerLiquids = {}
  self.transposerItems = {}
end

-- Create new T4Controller object from config
---@param config T4ControllerConfig
---@return T4Controller
function T4Controller:fromConfig(config)
  return T4Controller(config.hydrochloricAcidTransposerAddress, config.sodiumHydroxideTransposerAddress)
end

function T4Controller:gtInit()
  Controller.gtInit(self)

  self.hydrochloricAcidTransposerProxy = componentDiscoverLib.discoverProxy(
      self.hydrochloricAcidTransposerAddress,
      "[T4] Hydrochloric Acid Transposer",
      "transposer")
    self.sodiumHydroxideTransposerProxy = componentDiscoverLib.discoverProxy(
      self.sodiumHydroxideTransposerAddress,
      "[T4] Sodium Hydroxide Transposer",
      "transposer")

  self:findTransposerFluid(self.hydrochloricAcidTransposerProxy, "hydrochloricacid_gt5u")
  self:findTransposerItem(self.sodiumHydroxideTransposerProxy, "Sodium Hydroxide Dust")
end

function T4Controller:stateMachineInit()
  self.stateMachine.states.idle = self.stateMachine:createState("Idle")
  self.stateMachine.states.idle.update = function()
    if self.controllerProxy.hasWork() then
      self.stateMachine:setState(self.stateMachine.states.work)
    end
  end

  self.stateMachine.states.work = self.stateMachine:createState("Work")
  self.stateMachine.states.work.update = function()
    local phValue = self.gtSensorParser:getNumber(4, "Current pH Value:")

    if phValue == nil then
      return
    end

    local diffPh = 7 - phValue
    local count = math.floor(math.abs(diffPh / 0.01))

    if count == 0 then
      self.stateMachine:setState(self.stateMachine.states.waitEnd)
      return
    end

    if diffPh > 0 then
      self:putSodiumHydroxide(count)
    else
      self:putHydrochloricAcid(count)
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

---Find Transposer Item
---@param proxy transposer
---@param itemLabels string
function T4Controller:findTransposerItem(proxy, itemLabels)
  local result, skipped = componentDiscoverLib.discoverTransposerItemStorage(proxy, {itemLabels}, {sides.up})

  if #skipped ~= 0 then
    error("[T4] Can't find items: "..table.concat(skipped, ", "))
  end

  for key, value in pairs(result) do
    self.transposerItems[key] = value
  end
end

---Find side of transposer with fluid
---@param proxy transposer
---@param fluidName string
function T4Controller:findTransposerFluid(proxy, fluidName)
  local result, skipped = componentDiscoverLib.discoverTransposerFluidStorage(proxy, {fluidName}, {sides.up})

  if #skipped ~= 0 then
    error("[T4] Can't find liquid: "..table.concat(skipped, ", "))
  end

  for key, value in pairs(result) do
    self.transposerLiquids[key] = value
  end
end

---Put Sodium Hydroxide in input bus
---@param count integer
function T4Controller:putSodiumHydroxide(count)
  for i = 1, math.ceil(count / 64), 1 do
    local sodiumHydroxideCount = 0

    if (count - 64 * (i - 1) > 64) then
      sodiumHydroxideCount = 64
    else
      sodiumHydroxideCount = math.floor(count % 64)
    end

    local result = self.sodiumHydroxideTransposerProxy.transferItem(
      self.transposerItems["Sodium Hydroxide Dust"].side,
      sides.bottom,
      sodiumHydroxideCount)

    if result ~= sodiumHydroxideCount then
      self.controllerProxy.setWorkAllowed(false)
      event.push("log_warning", "[T4] Not enough Sodium Hydroxide for craft")
      break
    end
  end
end

---Put Hydrochloric Acid in input hatch
---@param count integer
function T4Controller:putHydrochloricAcid(count)
  local hydrochloricAcidCount = count * 10

  local _, result = self.hydrochloricAcidTransposerProxy.transferFluid(
    self.transposerLiquids["hydrochloricacid_gt5u"].side,
    sides.bottom,
    hydrochloricAcidCount,
    self.transposerLiquids["hydrochloricacid_gt5u"].tank)

  if result ~= hydrochloricAcidCount then
    self.controllerProxy.setWorkAllowed(false)
    event.push("log_warning", "[T4] Not enough Hydrochloric Acid for craft")
  end

  self.gtSensorParser = gtSensorParserLib:new(self.controllerProxy)
end

return T4Controller