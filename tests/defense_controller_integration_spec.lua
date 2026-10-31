-- Controller integration B42 mock: FOLLOW -> SHOVE -> PIN -> STOMP -> FOLLOW
-- and manual IDLE requested during fight (must not erase SELF_DEFEND).
package.path="42/media/lua/client/?.lua;42/media/lua/shared/?.lua;"..package.path
local clock=1000
getTimestampMs=function() return clock end
ZombRand=function() return 0 end
instanceof=function(o,typ) return o and o.kind==typ end
local zombies={}
local square={}
square.getMovingObjects=function()
    return {size=function() return #zombies end,
        get=function(_,i) return zombies[i+1] end}
end
getCell=function() return {getGridSquare=function() return square end} end
local movement={active=false,starts=0,cancels=0}
local Walking={
    active=function() return movement.active end,
    cancel=function()
        if movement.active then
            movement.active=false;movement.cancels=movement.cancels+1
        end
    end,
    update=function() end,
    pickNear=function() return square end,
    pickAround=function() return square end,
    pickRetreat=function() return square end,
    free=function() return true end,
    start=function()
        movement.active=true;movement.starts=movement.starts+1
        return true
    end
}
package.loaded["SupraNPC/NPCWalking"]=Walking
local Core=require("SupraNPC/Constants")
local Adapter=require("SupraNPC/SpawnAdapter")
local Controller=require("SupraNPC/NPCController")
local Defense=require("SupraNPC/NPCDefense")
Core.isSolo=function() return true end
local weapon={kind="HandWeapon",getMinDamage=function() return 0.3 end,
    getMaxDamage=function() return 0.5 end,getMaxRange=function() return 1.5 end,
    isAimedFirearm=function() return false end,isBroken=function() return false end}
local npc={kind="IsoPlayer",x=0,y=0}
function npc:getX() return self.x end
function npc:getY() return self.y end
function npc:getZ() return 0 end
function npc:getCurrentSquare() return square end
function npc:isDead() return false end
function npc:CanSee() return true end
function npc:getPrimaryHandItem() return weapon end
function npc:canPerformHandToHandCombat() return true end
function npc:faceThisObject() end
local md={SupraNPC_ID="npcA",SupraNPC_IsNPC=true}
function npc:getModData() return md end
local player={getX=function() return 7 end,
    getY=function() return 8 end,getZ=function() return 0 end,
    isDead=function() return false end}
local profile={id="npcA",firstName="Ana",lastName="Um",order="FOLLOW"}
local function newZombie()
    local z={kind="IsoZombie",dead=false,down=false,hp=0.8}
    function z:getX() return 1 end
    function z:getY() return 0.2 end
    function z:getZ() return 0 end
    function z:getCurrentSquare() return square end
    function z:isDead() return self.dead end
    function z:isOnFloor() return self.down end
    function z:isProne() return self.down end
    function z:isGettingUp() return false end
    function z:knockDown() self.down=true end
    function z:Hit(weaponUsed,who,damage)
        assert(who==npc and self.down)
        self.hp=self.hp-damage
        if self.hp<=0 then self.dead=true end
    end
    return z
end
local function ticks(n)
    for i=1,n do clock=clock+100;Controller.update(player) end
end
Adapter.actors.npcA=npc
Controller.clear()
assert(Controller.attach(profile,npc))
ticks(15)
assert(movement.starts==1 and movement.active)
local z1=newZombie()
zombies={z1}
ticks(15)
assert(Defense.STATES.npcA and z1.down)
assert(Controller.get("npcA").state.active=="SELF_DEFEND")
assert(Controller.get("npcA").state.requested=="FOLLOW")
assert(movement.cancels>=1)
ticks(15) -- STOMP: dentro de 1.35 tiles
assert(Controller.get("npcA").navStatus=="STOMP" and z1.hp<0.8)
npc.x=0.45
ticks(15)
assert(z1.dead)
ticks(15) -- resume original order and follow
assert(Controller.get("npcA").state.active=="FOLLOW")
assert(Controller.get("npcA").navStatus=="MOVING")
assert(movement.starts>=2)
-- New zombie: player changes requested order while SELF_DEFEND is active.
npc.x=0
local z2=newZombie()
zombies={z2}
ticks(15)
assert(z2.down and Controller.get("npcA").state.active=="SELF_DEFEND")
assert(Controller.order("npcA","IDLE",player))
assert(Controller.get("npcA").state.requested=="IDLE")
assert(Controller.get("npcA").state.active=="SELF_DEFEND")
ticks(15)
npc.x=0.45
ticks(30)
assert(z2.dead)
ticks(15)
assert(Controller.get("npcA").state.active=="IDLE")
assert(Controller.get("npcA").navStatus=="WAITING")
assert(not movement.active)
Controller.clear()
print("[SupraNPC] defense_controller_integration_spec: OK")
