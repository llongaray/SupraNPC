-- Regressao integrada: FOLLOW -> SELF_DEFEND -> FOLLOW, IDLE durante ataque.
package.path="42/media/lua/client/?.lua;42/media/lua/shared/?.lua;"..package.path
local clock=1000
getTimestampMs=function() return clock end
local zombies={}
instanceof=function(obj,typ) return obj and obj.kind==typ end
local square={}
square.getMovingObjects=function()
    return {size=function() return #zombies end,
        get=function(_,i) return zombies[i+1] end}
end
getCell=function() return {getGridSquare=function() return square end} end
local moveState={active=false,starts=0,cancels=0}
local walking={
    active=function() return moveState.active end,
    cancel=function(_,why)
        if moveState.active then
            moveState.active=false
            moveState.cancels=moveState.cancels+1
        end
    end,
    update=function() end,
    pickNear=function() return square end,
    pickAround=function() return square end,
    free=function() return true end,
    start=function()
        moveState.active=true
        moveState.starts=moveState.starts+1
        return true
    end
}
package.loaded["SupraNPC/NPCWalking"]=walking
local Core=require("SupraNPC/Constants")
local Adapter=require("SupraNPC/SpawnAdapter")
local Controller=require("SupraNPC/NPCController")
local Defense=require("SupraNPC/NPCDefense")
Core.isSolo=function() return true end
local weapon={kind="HandWeapon",getMinDamage=function() return 0.3 end,
    getMaxDamage=function() return 0.6 end,getMaxRange=function() return 1.5 end,
    isAimedFirearm=function() return false end}
local npc={
    kind="IsoPlayer",x=0,y=0,getX=function(self) return self.x end,
    getY=function(self) return self.y end,getZ=function() return 0 end,
    getCurrentSquare=function() return square end,isDead=function() return false end,
    CanSee=function() return true end,
    getPrimaryHandItem=function() return weapon end,
    faceThisObject=function() end
}
local md={SupraNPC_ID="npcA",SupraNPC_IsNPC=true}
npc.getModData=function() return md end
local player={getX=function() return 7 end,
    getY=function() return 8 end,getZ=function() return 0 end}
local profile={id="npcA",firstName="Ana",lastName="Um",order="FOLLOW"}
local function zombie()
    local z={kind="IsoZombie",dead=false,hp=0.8}
    function z:getX() return 1.0 end
    function z:getY() return 0.4 end
    function z:getZ() return 0 end
    function z:getCurrentSquare() return square end
    function z:isDead() return self.dead end
    function z:Hit(w,npcCaller,damage)
        assert(npcCaller==npc)
        self.hp=self.hp-damage
        if self.hp<=0 then self.dead=true end
        return damage
    end
    return z
end
Adapter.actors.npcA=npc
Controller.clear()
assert(Controller.attach(profile,npc))
for i=1,15 do clock=clock+100;Controller.update(player) end
assert(moveState.starts==1 and moveState.active)
local z1=zombie()
zombies={z1}
for i=1,15 do clock=clock+100;Controller.update(player) end
assert(Defense.STATES.npcA)
assert(Controller.get("npcA").state.active=="SELF_DEFEND")
assert(Controller.get("npcA").state.requested=="FOLLOW")
assert(moveState.cancels>=1)
local limit=0
while not z1.dead and limit<150 do
    limit=limit+1;clock=clock+100;Controller.update(player)
end
assert(z1.dead and limit<150)
for i=1,15 do clock=clock+100;Controller.update(player) end
assert(Controller.get("npcA").state.active=="FOLLOW")
assert(Controller.get("npcA").navStatus=="MOVING")
assert(moveState.starts>=2)

-- Novo zumbi: usuario seleciona IDLE enquanto batalha esta ativa.
local z2=zombie()
z2.hp=0.9
zombies={z2}
for i=1,15 do clock=clock+100;Controller.update(player) end
assert(Controller.get("npcA").state.active=="SELF_DEFEND")
assert(Controller.order("npcA","IDLE",player))
assert(Controller.get("npcA").state.requested=="IDLE")
assert(Controller.get("npcA").state.active=="SELF_DEFEND")
limit=0
while not z2.dead and limit<150 do
    clock=clock+100;Controller.update(player);limit=limit+1
end
assert(z2.dead)
for i=1,15 do clock=clock+100;Controller.update(player) end
assert(Controller.get("npcA").state.active=="IDLE")
assert(Controller.get("npcA").navStatus=="WAITING")
assert(not moveState.active)
Controller.clear()
print("[SupraNPC] defense_controller_integration_spec: OK")
