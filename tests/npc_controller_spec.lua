-- Comandos básicos: isolamento do jogador, salvar/retomar ordens, falha segura.
package.path = "42/media/lua/client/?.lua;42/media/lua/shared/?.lua;" .. package.path
local Core = require("SupraNPC/Constants")
local Adapter = require("SupraNPC/SpawnAdapter")
local Controller = require("SupraNPC/NPCController")
Core.isSolo = function() return true end

local md = {SupraNPC_ID="npc-A",SupraNPC_IsNPC=true}
local npc = {
    getModData = function() return md end,
    getX = function() return 10 end,
    getY = function() return 10 end,
    getZ = function() return 0 end,
    isDead = function() return false end,
    pathToCharacter = function(self, target) self.followRequests = (self.followRequests or 0)+1 end,
    pathToLocation = function(self,x,y,z) self.guardX=x self.guardY=y self.guardZ=z end
}
local player = {
    getX = function() return 15 end,
    getY = function() return 18 end,
    getZ = function() return 0 end
}
local profile = {id="npc-A",firstName="Ana",lastName="T",order="FOLLOW"}
Controller.clear()
Adapter.actors["npc-A"] = npc
assert(Controller.attach(profile, npc))
assert(not Controller.order("not-an-id","FOLLOW",player))
assert(not Controller.order("npc-A","ATTACK",player))
assert(not Controller.stance("npc-A","UNKNOWN"))
assert(Controller.stance("npc-A","PASSIVE"))
assert(md.SupraNPC_Stance == "PASSIVE" and profile.stance == "PASSIVE")
assert(Controller.order("npc-A","GUARD",player,"NPC"))
assert(profile.commandState.guardPoint.x == 10)
assert(Controller.order("npc-A","GUARD",player,"PLAYER"))
assert(profile.commandState.guardPoint.x == 15)
assert(profile.commandState.guardPoint.y == 18)
assert(Controller.order("npc-A","IDLE",player))
assert(md.SupraNPC_Order == "IDLE")
assert(Controller.order("npc-A","FOLLOW",player))
for i=1,45 do Controller.update(player) end
assert(npc.followRequests == 1)
assert(Controller.order("npc-A","GUARD",player,"NPC"))
for i=1,45 do Controller.update(player) end
assert(npc.guardX == 10 and npc.guardY == 10)
Controller.clear()
assert(Controller.attach(profile, npc))
assert(Controller.get("npc-A").state.requested == "GUARD")
Adapter.actors["npc-A"]=nil
assert(not Controller.attach(profile,npc))
Controller.clear()
print("[SupraNPC] npc_controller_spec: OK")
