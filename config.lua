local loggerLib = require("lib.logger-lib")
local discordLoggerHandler = require("lib.logger-handler.discord-logger-handler-lib")
local fileLoggerHandler = require("lib.logger-handler.file-logger-handler-lib")
local scrollListLoggerHandler = require("lib.logger-handler.scroll-list-logger-handler-lib")

local LineController = require("src.line-controller")
local QuantityController = require("src.quantity-controller")

local T1Controller = require("src.t1-controller")
local T2Controller = require("src.t2-controller")
local T3Controller = require("src.t3-controller")
local T4Controller = require("src.t4-controller")
local T5Controller = require("src.t5-controller")
local T6Controller = require("src.t6-controller")
local T7Controller = require("src.t7-controller")
local T8Controller = require("src.t8-controller")

local config = {
  enableAutoUpdate = true, -- Enable auto update on start

  logger = loggerLib:newFormConfig({
    name = "Water Line Control",
    timeZone = 3, -- Your time zone
    handlers = {
      discordLoggerHandler:newFormConfig({
        logLevel = "warning",
        messageFormat = "{Time:%d.%m.%Y %H:%M:%S} [{LogLevel}]: {Message}",
        discordWebhookUrl = "" -- Discord Webhook URL
      }),
      fileLoggerHandler:newFormConfig({
        logLevel = "debug",
        messageFormat = "{Time:%d.%m.%Y %H:%M:%S} [{LogLevel}]: {Message}",
        filePath = "logs.log"
      }),
        scrollListLoggerHandler:newFormConfig({
        logLevel = "debug",
        logsListSize = 32
      }),
    }
  }),

  lineController = LineController:fromConfig(),

  controllers = {
    t1 = { -- Controller for T1 Filtered Water (Grade 1)
      enable = true, -- Enable module for T1 water
      controller = T1Controller:fromConfig({})
    },
    t2 = { -- Controller for T2 Ozonated Water (Grade 2)
      enable = true, -- Enable module for T2 water
      controller = T2Controller:fromConfig({})
    },
    t3 = { -- Controller for T3 Flocculated Water (Grade 3)
      enable = true, -- Enable module for T3 water
      
      controller = T3Controller:fromConfig({
        transposerAddress = "0877c6dd-9421-4095-9dd1-8ecc1ae64cd9", -- Address of transposer which provides Polyaluminium Chloride
      })
    },
    
    t4 = { -- Controller for T4 pH Neutralized Water (Grade 4)
      enable = true, -- Enable module for T4 water
      controller = T4Controller:fromConfig({
        hydrochloricAcidTransposerAddress = "224ebf64-8bee-4874-aecb-a7ec7e620e8b", -- Address of transposer which provides Hydrochloric Acid
        sodiumHydroxideTransposerAddress = "ad8bacdb-f59a-44da-a108-2cd0b7571c8f" -- Address of transposer which provides Sodium Hydroxide Dust
      })
    },
    
    t5 = { -- Controller for T5 Extreme-Temperature Treated Water (Grade 5)
      enable = true, -- Enable module for T5 water
      controller = T5Controller:fromConfig({
        plasmaTransposerAddress = "c62f2acc-5360-492a-b4f8-bb54b2443c42", -- Address of transposer which provides Helium Plasma
        coolantTransposerAddress = "407b4e48-cec9-477e-bf62-52c646dafc31" -- Address of transposer which provides Super Coolant
      }),
    },
    
    t6 = { -- Controller for T6 Ultraviolet Treated Electrically Neutral Water (Grade 6)
      enable = true, -- Enable module for T6 water
      controller = T6Controller:fromConfig({
        transposerAddress = "47e85e04-504a-4879-96d4-dec16cb32825" -- Address of transposer which provides Lenses
      }),
    },
    
    t7 = { -- Controller for T7 Degassed Decontaminant-Free Water (Grade 7)
      enable = true, -- Enable module for T7 water
      controller = T7Controller:fromConfig({
        inertGasTransposerAddress = "ca439a44-802f-4cda-8b3d-764ca293a8bf", -- Address of transposer which provides Inert Gas
        superConductorTransposerAddress = "bb4505d0-9b03-4569-a7e9-68db134850b0", -- Address of transposer which provides Super Conductor
        netroniumTransposerAddress = "d4ed1081-a0ff-404e-a3d9-e754c1a575fd", -- Address of transposer which provides Molten Neutronium
        coolantTransposerAddress = "a151e083-a682-464c-a5e6-2bf1f30cf8d2" -- Address of transposer which provides Super Coolant
      }),
    },
    
    t8 = { -- Controller for T8 Subatomically Perfect Water (Grade 8)
      enable = true, -- Enable module for T8 water
      controller = T8Controller:fromConfig({
        maxQuarkCount = 4, -- Maximum number of each quark in the sub AE
        transposerAddress = "c8645157-d620-435a-8501-73934c5c4b3c", -- Address of transposer which provides Quarks
        subMeInterfaceAddress = "303d28ac-34b5-41a1-ba07-a702afcc09fc" -- Address of ME Interface which is connected to the sub AE network
      })
    }
  }
}

config.quantityController = QuantityController:fromConfig({
  baseConfig = config,
  controlMode = "singleThreadBalancing", -- "disabled", "multiThread", "singleThread", "singleThreadBalancing"
  meInterfaceAddress = "a1b2da71-b742-466f-86ce-dc8614756c1d",  -- Address of the ME Interface on the main/fluid storage network that should be monitored
  minQty = 32000,  -- The minimum quantity that will allow higher tiers to run. Set this to the highest amount used in a single cycle (which is based on the configured parallels). Only applies for controlMode="singleThreadBalancing". 
  waterThresholds = {
    -- Amount of each water to keep stocked (in L). Ignored if controlMode = "disabled"
    64000, -- T1
    64000, -- T2
    64000, -- T3
    64000, -- T4
    64000, -- T5
    64000, -- T6
    64000, -- T7
    64000  -- T8
  },
})

return config