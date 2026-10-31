-- Teste do spawn PROXY em ambiente simulado. Nao testa o motor PZ real.
package.path = "42/media/lua/client/?.lua;42/media/lua/shared/?.lua;" .. package.path
local Core = require("SupraNPC/Constants")
local Roster = require("SupraNPC/Roster")
local Adapter = require("SupraNPC/SpawnAdapter")

Core.isSolo = function() return true end
Core.EXPERIMENTAL_SPAWN = true

local md = {}
local actor = {
    getModData = function() return md end,
    setTarget = function() end,
    setNoTeeth = function() end,
    setUseless = function() end,
    setVariable = function() end,
    setDressInRandomOutfit = function() end,
    setFemaleEtc = function() end,
    setWalkType = function() end,
    getHumanVisual = function()
        return {
            setHairModel = function() end,
            setBeardModel = function() end,
            setSkinTextureIndex = function() end
        }
    end,
    resetModelNextFrame = function() end
}
local spawned = {}
local square = {
    getX = function() return 101 end,
    getY = function() return 100 end,
    getZ = function() return 0 end,
    getRoom = function() return "kitchen" end,
    isFree = function() return true end,
    isSolid = function() return false end
}
getCell = function()
    return { getGridSquare = function(_,x,y,z)
        if x == 101 and y == 100 and z == 0 then return square end
        if x == 100 and y == 101 and z == 0 then
            return {
                getX = function() return x end,
                getY = function() return y end,
                getZ = function() return z end,
                getRoom = function() return "kitchen" end,
                isFree = function() return true end,
                isSolid = function() return false end
            }
        end
        return nil
    end }
end
local player = {
    getX = function() return 100 end,
    getY = function() return 100 end,
    getZ = function() return 0 end,
    getSquare = function() return {getRoom = function() return "kitchen" end} end
}
addZombiesInOutfit = function(x,y,z,count,outfit,female)
    spawned[#spawned+1] = {x=x, y=y, z=z, count=count, outfit=outfit, female=female}
    local list={ size=function() return 1 end, get=function() return actor end }
    return list
end

local profiles = Roster.new(2).profiles
profiles[1].firstName = "Ana"
profiles[2].firstName = "Bruno"
profiles[2].female = true
local reserved = {}
local npc1, error1 = Adapter.spawn(player, profiles[1], reserved)
assert(npc1 == actor and error1 == nil)
assert(md.SupraNPC_ID == profiles[1].id)
assert(md.SupraNPC_Name == "Ana 1")
assert(md.SupraNPC_Proxy == true)
assert(md.SupraNPC_Order == "HOLD")
local npc2, error2 = Adapter.spawn(player, profiles[2], reserved)
assert(npc2 == actor and error2 == nil)
assert(#spawned == 2)
assert(spawned[1].x ~= spawned[2].x or spawned[1].y ~= spawned[2].y)
assert(spawned[2].female == 100)
local npc3, error3 = Adapter.spawn(player, profiles[2], reserved)
assert(npc3 == nil and error3 and error3:find("tile"))
Core.EXPERIMENTAL_SPAWN = false
local denied = Adapter.spawn(player, profiles[1], {})
assert(denied == nil)
print("[SupraNPC] teste de spawn proxy sem jogo: OK")
