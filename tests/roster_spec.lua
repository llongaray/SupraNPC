-- Testes puros Lua 5.1 (sem game runtime)
package.path = "42/media/lua/shared/?.lua;" .. package.path
local Core = require("SupraNPC/Constants")
local Roster = require("SupraNPC/Roster")
local Orders = require("SupraNPC/Orders")

assert(Core.clampCount(-3) == 0)
assert(Core.clampCount(99) == Core.MAX_COMPANIONS)
assert(Core.clampCount("3") == 3)
assert(Core.isSolo() == true)

local team = Roster.new(3)
assert(team.count == 3)
assert(#team.profiles == 3)
assert(team.profiles[1].id ~= team.profiles[2].id)
assert(Roster.validate(team))
team.profiles[1].skills.Fitness = 4
assert(team.profiles[2].skills.Fitness == nil)

local clone = Roster.copy(team)
clone.profiles[1].firstName = "Alterado"
assert(team.profiles[1].firstName == "NPC")
clone.profiles[1].traits[1] = "Brave"
assert(team.profiles[1].traits[1] == nil)

local invalid = Roster.new(1)
invalid.profiles[1] = nil
assert(not Roster.validate(invalid))

-- Perfis precisam estar individualmente completos antes do primeiro spawn.
assert(not Roster.validate(team, true))
team.profiles[1].complete = true
team.profiles[2].complete = true
team.profiles[3].complete = true
assert(Roster.validate(team, true))

local duplicate = Roster.copy(team)
duplicate.profiles[2].id = duplicate.profiles[1].id
assert(not Roster.validate(duplicate, true))

local badSkill = Roster.copy(team)
badSkill.profiles[1].skills.Fitness = 99
assert(not Roster.validate(badSkill, true))
badSkill.profiles[1].skills.Fitness = 4.5
assert(not Roster.validate(badSkill, true))

local badName = Roster.copy(team)
badName.profiles[1].firstName = "  "
assert(not Roster.validate(badName, true))

local state = Orders.new("FOLLOW")
assert(state.active == "FOLLOW")
assert(Orders.set(state, "GUARD"))
assert(state.active == "GUARD")
Orders.threat(state, true)
assert(state.active == "SELF_DEFEND")
assert(Orders.set(state, "FOLLOW"))
assert(state.active == "SELF_DEFEND")
Orders.threat(state, false)
assert(state.active == "FOLLOW")
assert(not Orders.set(state, "TELEPORT"))

print("[SupraNPC] testes de fichas e estados: OK")
