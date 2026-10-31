package.path="42/media/lua/client/?.lua;42/media/lua/shared/?.lua;"..package.path
local I=require("SupraNPC/NPCInputIsolation")
local primary={md={}}
local npc={md={SupraNPC_IsNPC=true,SupraNPC_ID="npc-1"}}
function primary:getModData() return self.md end
function npc:getModData() return self.md end
function npc:setIgnoreInputsForDirection(v) self.direction=v end
function npc:setIgnoreAimingInput(v) self.aim=v end
function npc:setIgnoreContextKey(v) self.context=v end
function npc:setJoypadBind(v) self.joypad=v end
local instance=nil
local localPlayer=nil
local camera=nil
IsoPlayer={
 setInstance=function(p) instance=p end,
 getInstance=function() return instance end,
 setLocalPlayer=function(index,p) assert(index==0);localPlayer=p end,
 getPlayer=function(index) assert(index==0);return localPlayer end,
}
IsoCamera={setCameraCharacter=function(p) camera=p end}
assert(I.isolate(primary,"npc-1")==false)
assert(I.isolate(npc,"bad-id")==false)
assert(I.isolate(npc,"npc-1")==true)
assert(npc.direction==true and npc.aim==true and npc.context==true)
assert(npc.joypad==-1)
-- NPC is NEVER the owner, even when game changes its getSpecificPlayer(0).
assert(I.remember(npc)==false)
assert(I.remember(primary))
assert(I.getOwner(npc)==primary)
instance=npc
localPlayer=npc
assert(I.restoreOwner(npc))
assert(instance==primary and localPlayer==primary and camera==primary)
local count=0
IsoPlayer.setLocalPlayer=function(i,p) count=count+1;localPlayer=p end
I.restoreOwner(npc)
assert(count==0) -- avoid replacing local player when already fixed
I.clear()
assert(I.getOwner(npc)==nil)
assert(I.getOwner(primary)==primary)
print("[SupraNPC] npc_input_isolation_spec: OK")
