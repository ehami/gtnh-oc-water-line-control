local Controller = require("src.controller")



--- @class T2Controller: Controller
local T2Controller = Controller:createChild()

function T2Controller:_init()
  Controller._init(self, "multimachine.purificationunitozonation", "[T2] Ozonation Purification Unit") -- call the base class constructor
end

--- @param config table
function T2Controller:newFromConfig(config)
    return self:_init()
end

return T2Controller