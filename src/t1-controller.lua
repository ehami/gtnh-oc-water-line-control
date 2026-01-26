local Controller = require("src.controller")

local T1Controller = {}

for k, v in pairs(Controller) do
  T1Controller[k] = v
end
T1Controller.__index = T1Controller


setmetatable(T1Controller, {
  __index = Controller, -- this is what makes the inheritance work
  __call = function (cls, ...)
    local self = setmetatable({}, cls)
    self:_init(...)
    return self
  end,
})

function T1Controller:_init()
  Controller._init(self, "multimachine.purificationunitclarifier", "[T1] Clarification Purification Unit") -- call the base class constructor
end

function T1Controller:newFromConfig(config)
    return self:_init()
end

return T1Controller