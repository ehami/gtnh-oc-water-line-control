local Controller = require("src.controller")



--- @class T1Controller: Controller
local T1Controller = Controller:createChild()

function T1Controller:_init()
  Controller._init(self, "multimachine.purificationunitclarifier", "[T1] Clarification Purification Unit") -- call the base class constructor
end

--- @param config table
function T1Controller:newFromConfig(config)
    return self:_init()
end

return T1Controller