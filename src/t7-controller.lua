local sides = require("sides")
local event = require("event")

local componentDiscoverLib = require("lib.component-discover-lib")

local Controller = require("src.controller")

---@class T7ControllerConfig
---@field inertGasTransposerAddress string
---@field superConductorTransposerAddress string
---@field netroniumTransposerAddress string
---@field coolantTransposerAddress string

---@class T7Controller: Controller
local T7Controller = Controller:createChild()

---Create new T7Controller object from config
---@param config T7ControllerConfig
---@return T7Controller
function T7Controller:fromConfig(config)
  return T7Controller(
    config.inertGasTransposerAddress,
    config.superConductorTransposerAddress,
    config.netroniumTransposerAddress,
    config.coolantTransposerAddress)
end

---Create new T7Controller object
---@param inertGasTransposerAddress string
---@param superConductorTransposerAddress string
---@param netroniumTransposerAddress string
---@param coolantTransposerAddress string
function T7Controller:_init(
  inertGasTransposerAddress,
  superConductorTransposerAddress,
  netroniumTransposerAddress,
  coolantTransposerAddress)
  Controller._init(self,"multimachine.purificationunitdegasifier", "[T7] Residual Decontaminant Degasser Purification Unit")

  self.inertGasTransposerAddress = inertGasTransposerAddress
  self.superConductorTransposerAddress = superConductorTransposerAddress
  self.netroniumTransposerAddress = netroniumTransposerAddress
  self.coolantTransposerAddress = coolantTransposerAddress

  self.inertGasTransposerProxy = nil
  self.superConductorTransposerProxy = nil
  self.netroniumTransposerProxy = nil
  self.coolantTransposerProxy = nil

  ---@type TransposerFluidStorageDescriptor[]
  self.transposerLiquids = {}

  self.superconductorCount = 1440
  self.neutroniumCount = 4608
  self.supercoolantCount = 10000
end

function T7Controller:gtInit()
  Controller.gtInit(self)

  self.inertGasTransposerProxy = componentDiscoverLib.discoverProxy(
    self.inertGasTransposerAddress,
    "[T7] Inert Gas Transposer",
    "transposer")
  self.superConductorTransposerProxy = componentDiscoverLib.discoverProxy(
    self.superConductorTransposerAddress,
    "[T7] Super Conductor Transposer",
    "transposer")
  self.netroniumTransposerProxy = componentDiscoverLib.discoverProxy(
    self.netroniumTransposerAddress,
    "[T7] Netronium Transposer",
    "transposer")
  self.coolantTransposerProxy = componentDiscoverLib.discoverProxy(
    self.coolantTransposerAddress,
    "[T7] Coolant Transposer",
    "transposer")

  self:findTransposerFluid(self.inertGasTransposerProxy, {"helium", "neon", "krypton", "xenon"})
  self:findTransposerFluid(self.superConductorTransposerProxy, {"superconductor"})
  self:findTransposerFluid(self.netroniumTransposerProxy, {"neutronium"})
  self:findTransposerFluid(self.coolantTransposerProxy, {"supercoolant"})

end

function T7Controller:stateMachineInit()
  self.stateMachine.states.idle = self.stateMachine:createState("Idle")
  self.stateMachine.states.idle.update = function()
    if self.gtSensorParser:getNumber(2, "Success chance:") == 100 then
      self.stateMachine:setState(self.stateMachine.states.waitEnd)
    elseif self.controllerProxy.hasWork() then
      self.stateMachine:setState(self.stateMachine.states.work)
    end
  end

  self.stateMachine.states.work = self.stateMachine:createState("Work")
  self.stateMachine.states.work.init = function()
    local bitString = self.gtSensorParser:getString(4, "Current control signal (binary): 0b")

    if bitString == nil then
      bitString = "0000"
    end

    local bits = self:bitParser(bitString)

    if bits[1] == false and bits[2] == false and bits[3] == false and bits[4] == false then
      self:putCoolant()
      self.stateMachine:setState(self.stateMachine.states.waitEnd)
      return
    end

    if bits[4] == true then
      self.stateMachine:setState(self.stateMachine.states.waitEnd)
      return
    end

    if bits[1] == true then
      self:putInertGas(bits)
    end

    if bits[2] == true then
      self:putSuperConductor()
    end

    if bits[3] == true then
      self:putNeutronium()
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
---@param proxy any
---@param fluidNames string[]
function T7Controller:findTransposerFluid(proxy, fluidNames)
  local result, skipped = componentDiscoverLib.discoverTransposerFluidStorage(proxy, fluidNames, {sides.up})

  if #skipped ~= 0 then
    error("[T7] Can't find liquid: "..table.concat(skipped, ", "))
  end

  for key, value in pairs(result) do
    self.transposerLiquids[key] = value
  end
end

---Parse bit string to bits array
---@param bitString string|number
---@return boolean[]
function T7Controller:bitParser(bitString)
  bitString = string.rep("0", 4 - #bitString)..bitString

  local bits = {
    tonumber(bitString:sub(4, 4)) == 1,
    tonumber(bitString:sub(3, 3)) == 1,
    tonumber(bitString:sub(2, 2)) == 1,
    tonumber(bitString:sub(1, 1)) == 1,
  }

  return bits
end

---Put inert gas in input hatch
---@param bits boolean[]
function T7Controller:putInertGas(bits)
  local inertGas = ""
  local count = 0

  if bits[2] == false and bits[3] == false then
    inertGas = "helium"
    count = 10000
  elseif bits[2] == true and bits[3] == false then
    inertGas = "neon"
    count = 7500
  elseif bits[2] == false and bits[3] == true then
    inertGas = "krypton"
    count = 5000
  elseif bits[2] == true and bits[3] == true then
    inertGas = "xenon"
    count = 2500
  end

  local _, result = self.inertGasTransposerProxy.transferFluid(
    self.transposerLiquids[inertGas].side,
    sides.up,
    count,
    self.transposerLiquids[inertGas].tank)

  if result ~= count then
    self.controllerProxy.setWorkAllowed(false)
    event.push("log_warning", "[T7] Not enough "..inertGas.." for craft")
  end
end

---Put super conductor in input hatch
function T7Controller:putSuperConductor()
  local _, result = self.superConductorTransposerProxy.transferFluid(
    self.transposerLiquids["superconductor"].side,
    sides.up,
    self.superconductorCount,
    self.transposerLiquids["superconductor"].tank)

  if result ~= self.superconductorCount then
    self.controllerProxy.setWorkAllowed(false)
    event.push("log_warning", "[T7] Not enough superconductor for craft")
  end
end

---Put super conductor in input hatch
function T7Controller:putNeutronium()
  local _, result = self.netroniumTransposerProxy.transferFluid(
    self.transposerLiquids["neutronium"].side,
    sides.up,
    self.neutroniumCount,
    self.transposerLiquids["neutronium"].tank)

  if result ~= self.neutroniumCount then
    self.controllerProxy.setWorkAllowed(false)
    event.push("log_warning", "[T7] Not enough neutronium for craft")
  end
end

---Put coolant in input hatch
function T7Controller:putCoolant()
  local _, result = self.coolantTransposerProxy.transferFluid(
    self.transposerLiquids["supercoolant"].side,
    sides.up,
    self.supercoolantCount,
    self.transposerLiquids["supercoolant"].tank)

  if result ~= self.supercoolantCount then
    self.controllerProxy.setWorkAllowed(false)
    event.push("log_warning", "[T7] Not enough coolant for craft")
  end
end

return T7Controller