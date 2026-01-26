local loggerLib = require("lib.logger-lib")
local discordLoggerHandler = require("lib.logger-handler.discord-logger-handler-lib")
local fileLoggerHandler = require("lib.logger-handler.file-logger-handler-lib")
local scrollListLoggerHandler = require("lib.logger-handler.scroll-list-logger-handler-lib")

local lineControllerLib = require("src.line-controller")

local t3controllerLib = require("src.t3-controller")
local t4controllerLib = require("src.t4-controller")
local t5controllerLib = require("src.t5-controller")
local t6controllerLib = require("src.t6-controller")
local t7controllerLib = require("src.t7-controller")
local t8controllerLib = require("src.t8-controller")
local metaControllerLib = require("src.meta-controller")

local config = {
  enableAutoUpdate = false, -- Enable auto update on start

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

  waterThresholds = {
    -- Amount of each water to keep stocked (in L)
    t1 = 10000,
    t2 = 10000,
    t3 = 10000,
    t4 = 10000,
    t5 = 10000,
    t6 = 10000,
    t7 = 10000,
    t8 = 10000
  },
  lineController = lineControllerLib:newFormConfig(),


  controllers = {
    t3 = { -- Controller for T3 Flocculated Water (Grade 3)
      enable = true, -- Enable module for T3 water
      metaController = metaControllerLib:new("multimachine.purificationunitflocculator"),
      controller = t3controllerLib:newFormConfig({
        transposerAddress = "0877c6dd-9421-4095-9dd1-8ecc1ae64cd9", -- Address of transposer which provide Polyaluminium Chloride
      }),
    },
    
    t4 = { -- Controller for T4 pH Neutralized Water (Grade 4)
      enable = true, -- Enable module for T4 water
      metaController = metaControllerLib:new("multimachine.purificationunitphadjustment"),
      controller = t4controllerLib:newFormConfig({
        hydrochloricAcidTransposerAddress = "224ebf64-8bee-4874-aecb-a7ec7e620e8b", -- Address of transposer which provide Hydrochloric Acid
        sodiumHydroxideTransposerAddress = "ad8bacdb-f59a-44da-a108-2cd0b7571c8f" -- Address of transposer which provide Sodium Hydroxide Dust
      }),
    },
    
    t5 = { -- Controller for T5 Extreme-Temperature Treated Water (Grade 5)
      enable = true, -- Enable module for T5 water
      metaController = metaControllerLib:new("multimachine.purificationunitplasmaheater"),
      controller = t5controllerLib:newFormConfig({
        plasmaTransposerAddress = "c62f2acc-5360-492a-b4f8-bb54b2443c42", -- Address of transposer which provide Helium Plasma
        coolantTransposerAddress = "407b4e48-cec9-477e-bf62-52c646dafc31" -- Address of transposer which provide Super Coolant
      }),
    },
    
    t6 = { -- Controller for T6 Ultraviolet Treated Electrically Neutral Water (Grade 6)
      enable = true, -- Enable module for T6 water
      metaController = metaControllerLib:new("multimachine.purificationunituvtreatment"),
      controller = t6controllerLib:newFormConfig({
        transposerAddress = "47e85e04-504a-4879-96d4-dec16cb32825" -- Address of transposer which provide Lenses
      }),
    },
    
    t7 = { -- Controller for T7 Degassed Decontaminant-Free Water (Grade 7)
      enable = true, -- Enable module for T7 water
      metaController = metaControllerLib:new("multimachine.purificationunitphadjustment"),
      controller = t7controllerLib:newFormConfig({
        inertGasTransposerAddress = "ca439a44-802f-4cda-8b3d-764ca293a8bf", -- Address of transposer which provide Inert Gas
        superConductorTransposerAddress = "bb4505d0-9b03-4569-a7e9-68db134850b0", -- Address of transposer which provide Super Conductor
        netroniumTransposerAddress = "d4ed1081-a0ff-404e-a3d9-e754c1a575fd", -- Address of transposer which provide Molten Neutronium
        coolantTransposerAddress = "a151e083-a682-464c-a5e6-2bf1f30cf8d2" -- Address of transposer which provide Super Coolant
      }),
    },
    
    t8 = { -- Controller for T8 Subatomically Perfect Water (Grade 8)
      enable = true, -- Enable module for T8 water
      metaController = metaControllerLib:new("multimachine.purificationunitphadjustment"),
      controller = t8controllerLib:newFormConfig({
        maxQuarkCount = 4, -- Maximum number of each quark in the sub AE
        transposerAddress = "c8645157-d620-435a-8501-73934c5c4b3c", -- Address of transposer which provide Quarks
        subMeInterfaceAddress = "303d28ac-34b5-41a1-ba07-a702afcc09fc" -- Address of me interface which connected to sub AE
      })
    }
  }
}

return config