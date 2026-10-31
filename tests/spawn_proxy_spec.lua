-- Regressao de seguranca: NUNCA criar zumbis como NPCs humanos.
-- O antigo spawn proxy foi bloqueado apos teste in-game B42.13.1.
package.path = "42/media/lua/client/?.lua;42/media/lua/shared/?.lua;" .. package.path

local Core = require("SupraNPC/Constants")
local Roster = require("SupraNPC/Roster")
local Adapter = require("SupraNPC/SpawnAdapter")

local count = 0
addZombiesInOutfit = function()
    count = count + 1
    error("Nao deveria ser chamado!")
end
IsoPlayer = { new = function()
    error("IsoPlayer.new nao foi validado em jogo normal")
end }

local player = {}
local profile = Roster.new(1).profiles[1]

-- Mesmo se alguem trocar uma configuracao manualmente, falhar fechado.
Core.EXPERIMENTAL_SPAWN = true
assert(Adapter.MODE == "disabled")
local entity, reason = Adapter.spawn(player, profile, {})
assert(entity == nil and type(reason) == "string")
assert(count == 0)

Core.EXPERIMENTAL_SPAWN = false
entity, reason = Adapter.spawn(player, profile, {})
assert(entity == nil and count == 0)

print("[SupraNPC] guard rail: nenhum zumbi gerado como NPC: OK")
