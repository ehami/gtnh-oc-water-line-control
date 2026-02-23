local Controller = require("src.controller")



---@class T2Controller: Controller
local T2Controller = Controller:createChild()

function T2Controller:_init()
  Controller._init(self, "multimachine.purificationunitozonation", "[T2] Ozonation Purification Unit") -- call the base class constructor
end

--- @param config table
--- @return T2Controller
function T2Controller:fromConfig(config)
    return T2Controller()
end

return T2Controller