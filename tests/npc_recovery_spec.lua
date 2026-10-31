package.path="42/media/lua/client/?.lua;42/media/lua/shared/?.lua;"..package.path
local Core=require("SupraNPC/Constants")
Core.isSolo=function() return true end
Core.EXPERIMENTAL_SPAWN=true
local actors={}
local remote={}
local spawns=0
local attached=0
local player={getX=function() return 100 end,getY=function() return 100 end,
    getZ=function() return 0 end}
local world={getGridSquare=function() return {} end}
getCell=function() return world end
local function actor(id)
  local npc={id=id,x=101,y=101,z=0}
  function npc:getX() return self.x end
  function npc:getY() return self.y end
  function npc:getZ() return self.z end
  function npc:isDead() return self.dead==true end
  return npc
end
local A={MODE="iso_player"}
A.get=function(id) return actors[id] end
A.findExisting=function(_,id) return remote[id] end
A.attach=function(id,npc) actors[id]=npc end
A.restoreOwner=function() end
A.spawn=function(_,profile)
   if actors[profile.id] or remote[profile.id] then
      return actors[profile.id] or remote[profile.id],nil,true
   end
   spawns=spawns+1
   local n=actor(profile.id)
   actors[profile.id]=n
   return n,nil,false
end
package.loaded["SupraNPC/SpawnAdapter"]=A
package.loaded["SupraNPC/NPCController"]={
    attach=function(_,npc) attached=attached+1;return npc~=nil end
}
package.loaded["SupraNPC/Roster"]={validate=function() return true end}
local R=require("SupraNPC/NPCRecovery")
local p={id="supranpc_1",firstName="Yong",humanSpawned=true}
local data={roster={profiles={p}},spawnStatus="human_spawned"}
-- Legacy save: no last-known location. No silent reconstruction.
R.update(player,data,900)
assert(spawns==0 and R.attempts[p.id]==nil)
-- Explicit repair keeps profile ID/name; repeating does not create clones.
local ok,reason=R.manual(player,data,p.id)
assert(ok and reason=="NPC recuperado" and spawns==1)
assert(p.humanSpawned and p.lastKnown and p.recoveryCount==1)
assert(R.manual(player,data,p.id)==true and spawns==1)
-- Game was closed: the secondary IsoPlayer is gone but the profile remains.
actors={}
R.reset()
R.update(player,data,90)
assert(spawns==1) -- wait until world/area streaming has finished
R.update(player,data,270)
assert(spawns==2 and p.recoveryCount==2 and attached>=2)
R.update(player,data,900)
assert(spawns==2) -- never respawn another duplicate this session
-- Existing actor in loaded world must be reattached, not respawned.
actors={}
remote[p.id]=actor(p.id)
R.reset()
R.update(player,data,270)
assert(actors[p.id]==remote[p.id] and spawns==2)
-- An in-world corpse with this ID is not a missing/live companion.
remote[p.id].dead=true
actors={}
p.deceased=false
p.humanSpawned=true
R.reset()
R.update(player,data,900)
assert(p.deceased and p.humanSpawned==false and spawns==2)
-- Legacy save may contain a corpse but no deceased flag.
p.deceased=false
p.humanSpawned=true
R.reset()
assert(R.manual(player,data,p.id)==false and spawns==2)
remote={}
p.deceased=false
p.humanSpawned=true
-- Last recorded position is far away: don't recreate offscreen NPC.
actors={}
p.lastKnown={x=400,y=400,z=0}
R.reset()
R.update(player,data,900)
assert(spawns==2 and not R.attempts[p.id])
-- A dead companion is never resurrected.
p.deceased=true
assert(R.manual(player,data,p.id)==false and spawns==2)
p.deceased=false
actors[p.id]=actor(p.id)
actors[p.id].dead=true
R.track(data)
assert(p.deceased and p.humanSpawned==false)
print("[SupraNPC] npc_recovery_spec: OK")
