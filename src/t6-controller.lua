local sides = require("sides")
local event = require("event")

local componentDiscoverLib = require("lib.component-discover-lib")

local Controller = require("src.controller")

---@class T6ControllerConfig
---@field transposerAddress string

---@class T6Controller: Controller
local T6Controller = Controller:createChild()

---Create new T6Controller object from config
---@param config T6ControllerConfig
---@return T6Controller
function T6Controller:fromConfig(config)
  return T6Controller(config.transposerAddress)
end

-- Create new T6Controller object
---@param transposerAddress string
function T6Controller:_init(transposerAddress)
  Controller._init(self, "multimachine.purificationunituvtreatment", "[T6] High Energy Laser Purification Unit")

  self.transposerAddress = transposerAddress
  self.transposerProxy = nil

  self.transposerItems = {}
end

function T6Controller:gtInit()
  Controller.gtInit(self)

  self.transposerProxy = componentDiscoverLib.discoverProxy(self.transposerAddress, "[T6] Transposer", "transposer")

  
  self:resetLenses()
  self:findTransposerItem(self.transposerProxy, {
    "Orundum Lens",
    "Amber Lens",
    "Aer Lens",
    "Emerald Lens",
    "Mana Diamond Lens",
    "Blue Topaz Lens",
    "Amethyst Lens",
    "Fluor-Buergerite Lens",
    "Dilithium Lens"
  })
end

function T6Controller:stateMachineInit()
  self.stateMachine.states.idle = self.stateMachine:createState("Idle")
  self.stateMachine.states.idle.init = function ()
    if self.stateMachine.data.currentLens ~= nil then
      self.transposerProxy.transferItem(
        sides.bottom, 
        self.transposerItems[self.stateMachine.data.currentLens].side,
        1,
        1,
        self.transposerItems[self.stateMachine.data.currentLens].slot)
    end
  end
  self.stateMachine.states.idle.update = function()
    if self.controllerProxy.hasWork() then
      self.stateMachine:setState(self.stateMachine.states.changeLens)
    end
  end

  self.stateMachine.states.changeLens = self.stateMachine:createState("Change Lens")
  self.stateMachine.states.changeLens.init = function()
    local lens = self.gtSensorParser:getString(5, "Current lens requested: ")
    local recipeError = self.gtSensorParser:getString(6)

    if lens == nil or recipeError == "Removed lens too early. Failing this recipe." then
      self.stateMachine:setState(self.stateMachine.states.waitEnd)
      return
    end

    self:putLens(lens)
  end

  self.stateMachine.states.waitLens = self.stateMachine:createState("Wait Lens")
  self.stateMachine.states.waitLens.update = function()
    local lens = self.gtSensorParser:getString(5, "Current lens requested: ")

    if self.controllerProxy.hasWork() == false then
      self.stateMachine:setState(self.stateMachine.states.idle)
      return
    end

    if self.stateMachine.data.currentLens ~= lens then
      self.stateMachine:setState(self.stateMachine.states.changeLens)
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

function T6Controller:resetLenses()
  local transposerSides = componentDiscoverLib.discoverTransposerItemStorageSide(self.transposerProxy, {sides.bottom})

  if transposerSides[1] ~= nil then
    self.transposerProxy.transferItem(sides.bottom, transposerSides[1], 1)
  end
end

---Put required lens to input bus
---@param lens string
function T6Controller:putLens(lens)
  if self.stateMachine.data.currentLens ~= nil then
    self.transposerProxy.transferItem(
      sides.bottom,
      self.transposerItems[self.stateMachine.data.currentLens].side,
      1,
      1,
      self.transposerItems[self.stateMachine.data.currentLens].slot)
  end

  if lens == "Dilithium Lens" and self.transposerItems[lens] == nil then
    self.stateMachine.data.currentLens = nil
    self.stateMachine:setState(self.stateMachine.states.waitEnd)
    return
  end

  local result = self.transposerProxy.transferItem(
    self.transposerItems[lens].side,
    sides.bottom,
    1,
    self.transposerItems[lens].slot)

  if result ~= 1 then
    self.controllerProxy.setWorkAllowed(false)
    self.stateMachine.data.currentLens = nil
    self.stateMachine:setState(self.stateMachine.states.waitEnd)
    event.push("log_warning", "[T6] Invalid slot: "..self.transposerItems[lens].slot.." for: "..lens)
    return
  end

  self.stateMachine.data.currentLens = lens

  if lens == "Dilithium Lens" then
    self.stateMachine:setState(self.stateMachine.states.waitEnd)
  else
    self.stateMachine:setState(self.stateMachine.states.waitLens)
  end
end


  ---Find Transposer Item
  ---@param proxy transposer
  ---@param itemLabels string[]
  function T6Controller:findTransposerItem(proxy, itemLabels)
    local result, skipped = componentDiscoverLib.discoverTransposerItemStorage(proxy, itemLabels)

    if #skipped ~= 0 then
      if not (#skipped == 1 and skipped[1] == "Dilithium Lens") then
        error("[T6] Can't find items: "..table.concat(skipped, ", "))
      end
    end

    for key, value in pairs(result) do
      self.transposerItems[key] = value
    end
  end

return T6Controller