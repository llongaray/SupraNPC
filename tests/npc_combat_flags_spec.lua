package.path="42/media/lua/client/?.lua;42/media/lua/shared/?.lua;"..package.path
local F=require("SupraNPC/NPCCombatFlags")
local function actor(id)
 local a={md={SupraNPC_IsNPC=true,SupraNPC_ID=id},god=true,inv=true,
    ignored=true,ghost=true,healthCheat=true,npc=false}
 function a:getModData() return self.md end
 function a:setNpc(v) self.npc=v end
 function a:isNpc() return self.npc end
 function a:setGodMod(v) self.god=v end
 function a:isGodMod() return self.god end
 function a:setInvulnerable(v) self.inv=v end
 function a:isInvulnerable() return self.inv end
 function a:setInvincible(v) self.invincible=v end
 function a:setHealthCheat(v) self.healthCheat=v end
 function a:setZombiesDontAttack(v) self.ignored=v end
 function a:isZombiesDontAttack() return self.ignored end
 function a:setGhostMode(v) self.ghost=v end
 function a:setInvisible(v) self.invisible=v end
 return a
end
local npc=actor("id1")
assert(F.configure(npc,"id1")==true)
assert(npc.npc and npc.god==false and npc.inv==false and npc.ignored==false)
assert(npc.ghost==false and npc.healthCheat==false)
local controlledPlayer=actor("player0")
controlledPlayer.md.SupraNPC_IsNPC=nil
assert(F.configure(controlledPlayer,"player0")==false)
assert(controlledPlayer.god and controlledPlayer.inv and controlledPlayer.ignored)
local otherNpc=actor("id2")
assert(F.configure(otherNpc,"id1")==false)
assert(otherNpc.god and otherNpc.inv)
-- Error in a native setter should not cause a crash or change player-0.
npc.setGodMod=function() error("unavailable") end
npc.god=true
local ok,why=F.configure(npc,"id1")
assert(ok==false and why=="native invulnerability persists")
print("[SupraNPC] npc_combat_flags_spec: OK")
