-- Configuracoes do SupraNPC: limites, defaults e falha segura.
package.path = "42/media/lua/shared/?.lua;" .. package.path
local Config = require("SupraNPC/Config")
local Core = require("SupraNPC/Constants")
local defaults = Config.defaults()
assert(defaults.followDistance == 1.3)
assert(defaults.maxCompanions == Core.MAX_COMPANIONS)
assert(defaults.autoDefend == true)
assert(Config.validate(defaults))

local clean, warnings = Config.sanitize({
    followDistance = 500,
    guardRadius = -9,
    thinkInterval = 9.5,
    lowHealthThreshold = 1/0,
    autoDefend = "no",
    maxCompanions = 100,
    unknown = 4
})
assert(clean.followDistance == 8)
assert(clean.guardRadius == 1)
assert(clean.thinkInterval == 9)
assert(clean.lowHealthThreshold == defaults.lowHealthThreshold)
assert(clean.autoDefend == true)
assert(clean.maxCompanions == Core.MAX_COMPANIONS)
assert(clean.unknown == nil)
assert(#warnings >= 6)
assert(Config.validate(clean))

local defaultsAgain = Config.defaults()
clean.followDistance = 4
assert(defaultsAgain.followDistance == 1.3)
local invalid = Config.sanitize("not table")
assert(invalid.followDistance == 1.3)
assert(not Config.validate({followDistance = 0/0}))
assert(not Config.validate({maxCompanions = 999}))
assert(not Config.validate({autoDefend = 1}))
assert(not Config.validate({unknown = 1}))
local stored = Config.forSave({followDistance=6, debug=true})
assert(stored.schema == 1 and stored.settings.followDistance == 6)
assert(stored.settings.debug == true)
assert(Core.EXPERIMENTAL_SPAWN == true or Core.EXPERIMENTAL_SPAWN == false)
print("[SupraNPC] config_spec: OK")
