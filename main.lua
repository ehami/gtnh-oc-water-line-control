local keyboard = require("keyboard")

local programLib = require("lib.program-lib")
local guiLib = require("lib.gui-lib")

local scrollList = require("lib.gui-widgets.scroll-list")

package.loaded.config = nil
local config = require("config")

local version = require("version")

local repository = "ehami/GTNH-OC-Water-Line-Control"
local archiveName = "WaterLineControl"

local program = programLib:new(config.logger, config.enableAutoUpdate, version, repository, archiveName)
local gui = guiLib:new(program)

local logo = {
  "__        __    _              _     _               ____            _             _ ",
  "\\ \\      / /_ _| |_ ___ _ __  | |   (_)_ __   ___   / ___|___  _ __ | |_ _ __ ___ | |",
  " \\ \\ /\\ / / _` | __/ _ \\ '__| | |   | | '_ \\ / _ \\ | |   / _ \\| '_ \\| __| '__/ _ \\| |",
  "  \\ V  V / (_| | ||  __/ |    | |___| | | | |  __/ | |__| (_) | | | | |_| | | (_) | |",
  "   \\_/\\_/ \\__,_|\\__\\___|_|    |_____|_|_| |_|\\___|  \\____\\___/|_| |_|\\__|_|  \\___/|_|"
}

local mainTemplate = {
  width = 60,
  background = gui.palette.black,
  foreground = gui.palette.white,
  widgets = {
    logsScrollList = scrollList:new("logsScrollList", "logs", keyboard.keys.up, keyboard.keys.down)
  },
  lines = {
    "Line State: $lineState$ | (Q)uit (Up)/(Down) Arrow",
    "T_: Quantity /   Requested | (Success %) - State",
    "T1: $t1waterLevel$ | ($t1success$) - $t1state$",
    "T2: $t2waterLevel$ | ($t2success$) - $t2state$",
    "T3: $t3waterLevel$ | ($t3success$) - $t3state$",
    "T4: $t4waterLevel$ | ($t4success$) - $t4state$",
    "T5: $t5waterLevel$ | ($t5success$) - $t5state$",
    "T6: $t6waterLevel$ | ($t6success$) - $t6state$",
    "T7: $t7waterLevel$ | ($t7success$) - $t7state$",
    "T8: $t8waterLevel$ | ($t8success$) - $t8state$",
    "",
    "#logsScrollList#",
    "#logsScrollList#",
    "#logsScrollList#",
    "#logsScrollList#",
    "#logsScrollList#",
    "#logsScrollList#",
    "#logsScrollList#",
    "#logsScrollList#"
  }
}

local controllerStates = {
  ["t1"] = config.controllers.t1.enable and "Loading" or "Unused",
  ["t2"] = config.controllers.t2.enable and "Loading" or "Unused",
  ["t3"] = config.controllers.t3.enable and "Loading" or "Unused",
  ["t4"] = config.controllers.t4.enable and "Loading" or "Unused",
  ["t5"] = config.controllers.t5.enable and "Loading" or "Unused",
  ["t6"] = config.controllers.t6.enable and "Loading" or "Unused",
  ["t7"] = config.controllers.t7.enable and "Loading" or "Unused",
  ["t8"] = config.controllers.t8.enable and "Loading" or "Unused",
}

local controllerSuccesses = {
  ["t1"] = 0,
  ["t2"] = 0,
  ["t3"] = 0,
  ["t4"] = 0,
  ["t5"] = 0,
  ["t6"] = 0,
  ["t7"] = 0,
  ["t8"] = 0,
}

local function init()
  gui:setTemplate(mainTemplate)
end

local function initControllers()
  os.sleep(0.5)
  config.lineController:init()
  config.quantityController:gtInit()

  for i = 1, 8, 1 do
    local key = "t"..i

    if config.controllers[key].enable then
      config.controllers[key].controller:gtInit()
      config.controllers[key].controller:stateMachineInit()
    end
  end
end

local function loop()
  initControllers()

  while true do
    config.quantityController:loop()
    config.lineController:loop()

    for i = 1, 8, 1 do
      local key = "t"..i

      if config.controllers[key].enable then
        config.controllers[key].controller:loop()
        controllerStates[key] = config.controllers[key].controller:getState()
        controllerSuccesses[key] = config.controllers[key].controller:getSuccess()
      end

      os.sleep(0.1)
    end

    os.sleep(1)
  end
end

local function guiLoop()
  gui:render({
    lineState = config.lineController:getState(),
    t1state = controllerStates["t1"],
    t2state = controllerStates["t2"],
    t3state = controllerStates["t3"],
    t4state = controllerStates["t4"],
    t5state = controllerStates["t5"],
    t6state = controllerStates["t6"],
    t7state = controllerStates["t7"],
    t8state = controllerStates["t8"],
    t1success = controllerSuccesses["t1"],
    t2success = controllerSuccesses["t2"],
    t3success = controllerSuccesses["t3"],
    t4success = controllerSuccesses["t4"],
    t5success = controllerSuccesses["t5"],
    t6success = controllerSuccesses["t6"],
    t7success = controllerSuccesses["t7"],
    t8success = controllerSuccesses["t8"],
    t1waterLevel = string.format("%8d / %8d kL", (config.quantityController.waterLevels[1]/1000), config.quantityController.waterThresholds[1]/1000),
    t2waterLevel = string.format("%8d / %8d kL", (config.quantityController.waterLevels[2]/1000), config.quantityController.waterThresholds[2]/1000),
    t3waterLevel = string.format("%8d / %8d kL", (config.quantityController.waterLevels[3]/1000), config.quantityController.waterThresholds[3]/1000),
    t4waterLevel = string.format("%8d / %8d kL", (config.quantityController.waterLevels[4]/1000), config.quantityController.waterThresholds[4]/1000),
    t5waterLevel = string.format("%8d / %8d kL", (config.quantityController.waterLevels[5]/1000), config.quantityController.waterThresholds[5]/1000),
    t6waterLevel = string.format("%8d / %8d kL", (config.quantityController.waterLevels[6]/1000), config.quantityController.waterThresholds[6]/1000),
    t7waterLevel = string.format("%8d / %8d kL", (config.quantityController.waterLevels[7]/1000), config.quantityController.waterThresholds[7]/1000),
    t8waterLevel = string.format("%8d / %8d kL", (config.quantityController.waterLevels[8]/1000), config.quantityController.waterThresholds[8]/1000),

    logs = config.logger.handlers[3]["logs"].list
  })
end

local function onExit()
  config.lineController:disable()
end

program:registerLogo(logo)
program:registerInit(init)
program:registerOnExit(onExit)
program:registerThread(loop)
program:registerTimer(guiLoop, math.huge, 1)
program:start()