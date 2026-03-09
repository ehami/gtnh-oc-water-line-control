local event = require("event")

local componentDiscoverLib = require("lib.component-discover-lib")


---@class QuantityControllerConfig
---@field baseConfig table
---@field controlMode "disabled" |  "multiThread" | "singleThread" | "singleThreadBalancing"
---@field meInterfaceAddress string
---@field waterThresholds table
---@field minQty number

---@class QuantityController
---@field controllers table<string, {enable: boolean, controller: Controller}>
local QuantityController = {}
QuantityController.__index = QuantityController

setmetatable(QuantityController, {
  __call = function (cls, ...)
    local self = setmetatable({}, cls)
    self:_init(...)
    return self
  end,
})

---@param config QuantityControllerConfig
---@return QuantityController
function QuantityController:fromConfig(config)
  return QuantityController(
    config.baseConfig.controllers,
    config.controlMode,
    config.waterThresholds,
    config.meInterfaceAddress,
    config.minQty
  )
end

function QuantityController:_init(controllers, controlMode, waterThresholds, meInterfaceAddress, minQty)
  self.controllers = controllers
  self.controlMode = controlMode
  self.waterThresholds = waterThresholds
  self.meInterfaceAddress = meInterfaceAddress
  self.minQty = minQty
  self.isTierActive = {false, false, false, false, false, false, false, false}

  self.meInterfaceProxy = nil

  self.waterNames =  {
    "grade1purifiedwater",
    "grade2purifiedwater",
    "grade3purifiedwater",
    "grade4purifiedwater",
    "grade5purifiedwater",
    "grade6purifiedwater",
    "grade7purifiedwater",
    "grade8purifiedwater",
    "stablebaryonicmatter",
  }

  self.waterLevels = {0, 0, 0, 0, 0, 0, 0, 0, 0}
end

function QuantityController:gtInit()
  self.meInterfaceProxy = componentDiscoverLib.discoverProxy(self.meInterfaceAddress, "[QC] ME Interface", "me_interface")

  if self.meInterfaceProxy == nil then
    event.push("log_error", "[QC] Could not find me interface to monitor")
  end

  event.listen("cycle_pre_end", function ()
    -- event.push("log_error", "cycle_pre_end fired")
    self:updateWaterLevels()
    self:updateControllerEnablement()
  end)

  self:updateWaterLevels()
end

--- @param i integer
--- @return integer
local function iTier(i)
  if i == 9 then
    return 8
  end

  return i
end

--- @param i integer
--- @return string
local function sTier(i)
  return "t"..iTier(i)
end

function QuantityController:updateControllerEnablement()
  local function clearActiveTiers()
    for i = 1,8 do
      self.isTierActive[iTier(i)] = (false)
    end
  end

  if self.controlMode == "disabled" then
    -- No-op
    return
  end

  if self.controlMode == "multiThread" then
    -- Enable all tiers that are below their thresholds
    for i = 1,8 do
      if self.controllers[sTier(i)].enable then
        if i == 8 then
          self.isTierActive[iTier(i)] = (
            self.waterLevels[i] < self.waterThresholds[i]
            or self.waterLevels[9] < self.waterThresholds[9]
          )
        else
          self.isTierActive[iTier(i)] = (
            self.waterLevels[i] < self.waterThresholds[i]
          )
        end
      end
    end
  end

  if  self.controlMode == "singleThread" then
    -- Enable the lowest tier that is below its threshold
    clearActiveTiers()

    for i = 1,9 do
      if self.controllers[sTier(i)].enable and self.waterLevels[i] < self.waterThresholds[i] then
        self.isTierActive[iTier(i)] = true
        break
      end
    end
  end

  if self.controlMode == "singleThreadBalancing" then
    -- Enable the tier with the lowest water level (that's below its threshold). Lower tiers win ties. Do not bypass a tier if below minQty
    clearActiveTiers()

    local winningTier = -1

    for i = 1,9 do
      if self.controllers[sTier(i)].enable and self.waterLevels[i] < self.waterThresholds[i] then
        if winningTier == -1 or self.waterLevels[i] < self.waterLevels[winningTier] or self.waterLevels[i] < self.minQty then
          winningTier = i

          if self.waterLevels[i] < self.minQty then
            break
          end
        end
      end
    end

    if winningTier ~= -1 then
      self.isTierActive[iTier(winningTier)] = true
    end
  end

  -- Apply Active Tiers (Defensively to avoid a race condition)
  for i = 1,8 do
    self.controllers[sTier(i)].controller:setEnabled(false)
  end

  for i = 1,8 do
    self.controllers[sTier(i)].controller:setEnabled(self.isTierActive[iTier(i)])
  end
end

function QuantityController:loop()
  self:updateWaterLevels()
end

function QuantityController:updateWaterLevels()
  for i, _ in ipairs(self.waterLevels) do
    self.waterLevels[i] = 0
  end

  if self.meInterfaceProxy == nil then
    return
  end

  for _, fluid in ipairs(self.meInterfaceProxy.getFluidsInNetwork()) do
    for i, fluidName in ipairs(self.waterNames) do

      if fluidName == fluid.name then
        self.waterLevels[i] = fluid.amount
      end
    end
  end
end

return QuantityController
