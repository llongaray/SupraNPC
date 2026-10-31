-- Regressao do pathfinding nativo da entidade humana (mock sem PZ).
package.path = "42/media/lua/client/?.lua;42/media/lua/shared/?.lua;" .. package.path
local Core = require("SupraNPC/Constants")
local Adapter = require("SupraNPC/SpawnAdapter")
local Controller = require("SupraNPC/NPCController")
Core.isSolo = function() return true end

local calls={follow=0,guard=0,update=0,cancel=0}
local behavior={
    pathToCharacter=function(self,player)
        calls.follow=calls.follow+1
    end,
    pathToLocation=function(self,x,y,z)
        calls.guard=calls.guard+1
    end,
    update=function()
        calls.update=calls.update+1
        return "Working"
    end,
    cancel=function()
        calls.cancel=calls.cancel+1
    end
}
local md={SupraNPC_ID="A1",SupraNPC_IsNPC=true}
local actor={
    getModData=function() return md end,
    getX=function() return 0 end,
    getY=function() return 0 end,
    getZ=function() return 0 end,
    isDead=function() return false end,
    getPathFindBehavior2=function() return behavior end
}
local player={
    getX=function() return 10 end,
    getY=function() return 12 end,
    getZ=function() return 0 end
}
local profile={id="A1",firstName="Ana",lastName="R",order="FOLLOW"}
Adapter.actors["A1"]=actor
Adapter.restoreOwner=function() end
Controller.clear()
assert(Controller.attach(profile,actor))
for i=1,12 do Controller.update(player) end
assert(calls.follow==1 and calls.update>=12)
assert(Controller.order("A1","IDLE",player))
assert(calls.cancel>=1)
local updates=calls.update
for i=1,12 do Controller.update(player) end
assert(calls.update==updates)
assert(Controller.order("A1","GUARD",player,"PLAYER"))
for i=1,12 do Controller.update(player) end
assert(calls.guard==1 and calls.update>updates)
assert(Controller.order("A1","FOLLOW",player))
for i=1,12 do Controller.update(player) end
assert(calls.follow>=2)

-- Falha da API de pathfinding nao deve enviar teleporte ou novo NPC.
Controller.clear()
Adapter.actors["A1"]=actor
assert(Controller.attach(profile,actor))
local failedPath={
    pathToCharacter=function() end,
    update=function() error("Path engine indisponivel") end
}
actor.getPathFindBehavior2=function() return failedPath end
local before=Controller.get("A1").navTries
for i=1,15 do Controller.update(player) end
assert(Controller.get("A1").navTries > before)
assert(Controller.get("A1").navDisabled==true)
print("[SupraNPC] movement_behavior_spec: OK")
