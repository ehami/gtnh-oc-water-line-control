local Controller = require("src.controller")



--- @class T1Controller: Controller
local T1Controller = Controller:createChild()

function T1Controller:_init()
  Controller._init(self, "multimachine.purificationunitclarifier", "[T1] Clarification Purification Unit") -- call the base class constructor
end

--- @param config table
--- @return T1Controller
function T1Controller:fromConfig(config)
    return T1Controller()
end

return T1Controller