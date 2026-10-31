-- Estados e isolamento de ordens com adaptador de caminhada simulado.
package.path="42/media/lua/client/?.lua;42/media/lua/shared/?.lua;"..package.path
local starts,stops,active={},{},{}
local Walking={
    cancel=function(id) stops[id]=(stops[id] or 0)+1;active[id]=nil end,
    active=function(id) return active[id]==true end,
    update=function() end,
    pickNear=function() return {getX=function() return 12 end} end,
    pickAround=function() return {getX=function() return 12 end} end,
    free=function() return true end,
    start=function(id,npc,sq,cb)
        starts[id]=(starts[id] or 0)+1;active[id]=true
        return true
    end
}
package.loaded["SupraNPC/NPCWalking"]=Walking
local Core=require("SupraNPC/Constants")
local Adapter=require("SupraNPC/SpawnAdapter")
local Controller=require("SupraNPC/NPCController")
Core.isSolo=function() return true end
local md={SupraNPC_ID="npc-A",SupraNPC_IsNPC=true}
local npc={
    getModData=function() return md end,
    getX=function() return 10 end,
    getY=function() return 10 end,
    getZ=function() return 0 end,
    isDead=function() return false end
}
local player={getX=function() return 15 end,
    getY=function() return 18 end,getZ=function() return 0 end}
local profile={id="npc-A",firstName="Ana",lastName="T",order="FOLLOW"}
Controller.clear()
Adapter.actors["npc-A"]=npc
assert(Controller.attach(profile,npc))
assert(not Controller.order("nao-existe","FOLLOW",player))
assert(not Controller.order("npc-A","ATTACK",player))
assert(not Controller.stance("npc-A","UNKNOWN"))
assert(Controller.stance("npc-A","PASSIVE"))
assert(md.SupraNPC_Stance=="PASSIVE" and profile.stance=="PASSIVE")
assert(Controller.order("npc-A","GUARD",player,"NPC"))
assert(profile.commandState.guardPoint.x==10)
assert(Controller.order("npc-A","GUARD",player,"PLAYER"))
assert(profile.commandState.guardPoint.x==15 and
    profile.commandState.guardPoint.y==18)
-- Guardar ponto distante usa walking por NPC.
getCell=function() return {
    getGridSquare=function() return {} end
} end
for i=1,15 do Controller.update(player) end
assert(starts["npc-A"]==1)
assert(Controller.order("npc-A","IDLE",player))
assert(md.SupraNPC_Order=="IDLE")
for i=1,20 do Controller.update(player) end
assert(starts["npc-A"]==1 and not Walking.active("npc-A"))
assert(Controller.order("npc-A","FOLLOW",player))
for i=1,15 do Controller.update(player) end
assert(starts["npc-A"]==2)
Controller.clear()
assert(Controller.attach(profile,npc))
assert(Controller.get("npc-A").state.requested=="FOLLOW")
Adapter.actors["npc-A"]=nil
assert(not Controller.attach(profile,npc))
Controller.clear()
print("[SupraNPC] npc_controller_spec: OK")
