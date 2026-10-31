-- Regressao: criar IsoPlayer humano de verdade, NUNCA IsoZombie.
package.path = "42/media/lua/client/?.lua;42/media/lua/shared/?.lua;" .. package.path

local Core = require("SupraNPC/Constants")
local Roster = require("SupraNPC/Roster")
local Adapter = require("SupraNPC/SpawnAdapter")
Core.isSolo = function() return true end
Core.EXPERIMENTAL_SPAWN = true

local zombieCalls = 0
addZombiesInOutfit = function()
    zombieCalls = zombieCalls + 1
    error("Um NPC humano nao pode ser gerado como IsoZombie!")
end

local localPlayer = nil
local cameraPlayer = nil
local created = {}
local list = {
    size = function() return 0 end,
    contains = function() return false end,
    add = function() end
}
local square = function(x,y)
    local s = { x=x, y=y }
    function s:getX() return self.x end
    function s:getY() return self.y end
    function s:getZ() return 0 end
    function s:TreatAsSolidFloor() return true end
    function s:isFree() return true end
    function s:getRoom() return "room" end
    function s:getMovingObjects() return list end
    return s
end
local square1,square2=square(101,100),square(99,100)
local cell = {}
function cell:getGridSquare(x,y,z)
    if x==101 and y==100 and z==0 then return square1 end
    if x==99 and y==100 and z==0 then return square2 end
end
function cell:getObjectList() return list end
getCell = function() return cell end

local player = {x=100,y=100,z=0}
function player:getX() return self.x end
function player:getY() return self.y end
function player:getZ() return self.z end
function player:getSquare() return {getRoom=function() return "room" end} end
IsoCamera = {setCameraCharacter = function(x) cameraPlayer=x end}
IsoPlayer = {}
IsoPlayer.setInstance = function(x) localPlayer=x end

SurvivorFactory = {}
SurvivorFactory.CreateSurvivor = function()
    return {
        setForename=function(self,value) self.firstName=value end,
        setSurname=function(self,value) self.lastName=value end,
        setFemale=function(self,value) self.female=value end,
        getHumanVisual=function()
            return {
                setHairModel=function() end,
                setBeardModel=function() end,
                setSkinTextureIndex=function() end
            }
        end
    }
end

local failCreation = false
IsoPlayer.new = function(cellValue, desc, x,y,z)
    if failCreation then error("falha simulada do motor") end
    assert(cellValue == cell)
    local a = {desc=desc,x=x,y=y,z=z,md={}}
    function a:getBodyDamage() return {} end
    function a:getModData() return self.md end
    function a:setNPC(value) self.npc=value end
    function a:removeFromSquare() end
    function a:teleportTo(ax,ay,az) self.x,self.y,self.z=ax,ay,az end
    function a:setX(v) self.x=v end
    function a:setY(v) self.y=v end
    function a:setZ(v) self.z=v end
    function a:setLastX() end
    function a:setLastY() end
    function a:setNextX() end
    function a:setNextY() end
    function a:setScriptNextX() end
    function a:setScriptNextY() end
    function a:setCurrentSquareFromPosition() end
    function a:getCurrentSquare()
        return self.x<100 and square2 or square1
    end
    function a:setCurrent() end
    function a:setSceneCulled() end
    function a:setAlpha() end
    function a:setTargetAlpha() end
    function a:resetModelNextFrame() end
    function a:getInventory() return {AddItem=function() end} end
    created[#created+1]=a
    return a
end

local roster = Roster.new(2)
roster.profiles[1].firstName="Ana"
roster.profiles[2].firstName="Bruno"
roster.profiles[2].female=true
local reserved={}
local npc1,err1,reused1=Adapter.spawn(player,roster.profiles[1],reserved)
assert(npc1 and err1==nil and reused1==false)
assert(npc1.npc==true and npc1.md.SupraNPC_Engine=="IsoPlayer")
assert(npc1.md.SupraNPC_ID == roster.profiles[1].id)
assert(npc1.desc.firstName=="Ana")
assert(localPlayer==player and cameraPlayer==player)
local npc2,err2,reused2=Adapter.spawn(player,roster.profiles[2],reserved)
assert(npc2 and err2==nil and reused2==false)
assert(npc2.md.SupraNPC_ID==roster.profiles[2].id)
assert(npc2.desc.female==true)
assert(math.floor(npc1.x)~=math.floor(npc2.x))
assert(#created==2 and zombieCalls==0)
assert(localPlayer==player and cameraPlayer==player)

local again,reason,reused=Adapter.spawn(player,roster.profiles[1],reserved)
assert(again==npc1 and reason==nil and reused==true and #created==2)

Core.EXPERIMENTAL_SPAWN=false
assert(Adapter.spawn(player,roster.profiles[1],{}) == nil)
Core.EXPERIMENTAL_SPAWN=true
Adapter.clear()
failCreation=true
local failed,why=Adapter.spawn(player,roster.profiles[1],{})
assert(failed==nil and type(why)=="string")
assert(localPlayer==player and cameraPlayer==player)
assert(zombieCalls==0)
print("[SupraNPC] spawn IsoPlayer, controle de jogador e bloqueio zombie: OK")
