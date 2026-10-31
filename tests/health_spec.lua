-- Validacoes de leitura de saude sem API do Project Zomboid.
package.path = "42/media/lua/client/?.lua;42/media/lua/shared/?.lua;" .. package.path
local Health = require("SupraNPC/Health")

local absent = Health.inspect(nil, {id="npc1", firstName="Ana", lastName="Lima"})
assert(absent.available == false and absent.health == nil)
assert(absent.reason == "Entidade indisponivel")

local part1 = {
    getType = function() return "Hand_L" end,
    bleeding = function() return true end,
    bitten = function() return false end,
    scratched = function() return true end,
    bandaged = function() return true end,
    getFractureTime = function() return 0 end
}
local part2 = {
    getType = function() return "Leg_R" end,
    bleeding = function() return false end,
    getFractureTime = function() return 18 end
}
local parts = {
    size = function() return 2 end,
    get = function(_,i) return i == 0 and part1 or part2 end
}
local damage = {
    getOverallBodyHealth = function() return 72.3 end,
    getBodyParts = function() return parts end
}
local stats = {
    getPain = function() return 20 end,
    getHunger = function() return 0.4 end,
    getThirst = function() return 0.6 end,
    getEndurance = function() return 0.9 end
}
local npc = {
    isDead = function() return false end,
    getBodyDamage = function() return damage end,
    getStats = function() return stats end
}
local examined = Health.inspect(npc,{id="npc2",firstName="Bruno",lastName="Reis"})
assert(examined.available and examined.health == 72.3)
assert(examined.name == "Bruno Reis")
assert(examined.pain == 20 and examined.hunger == 0.4)
assert(examined.bleeding == true and #examined.injuries == 2)
assert(examined.injuries[1].part == "Hand_L")
assert(examined.injuries[2].signs == "Fratura")
local emptyBody = {getBodyDamage = function()
    return { getBodyParts = function() return parts end }
end}
assert(Health.inspect(emptyBody).health == nil) -- Nunca inventar 100% de vida.
print("[SupraNPC] health_spec: OK")


-- B42: os getters antigos de Stats foram substituidos pelo enum CharacterStat.
CharacterStat={HUNGER="H",THIRST="T",ENDURANCE="E",PAIN="P"}
local values={H=0.25,T=0.75,E=0.63,P=18}
local b42={get=function(_,key) return values[key] end}
local npc42={
    getBodyDamage=function() return {
        getHealth=function() return 97 end,
        getBodyParts=function() return {size=function() return 0 end} end
    } end,
    getStats=function() return b42 end
}
local measured=Health.inspect(npc42)
assert(measured.available and measured.health==97)
assert(measured.hunger==0.25 and measured.thirst==0.75)
assert(measured.endurance==0.63 and measured.pain==18)
assert(measured.sources.hunger and measured.sources.thirst)
print("[SupraNPC] health B42 CharacterStat: OK")
