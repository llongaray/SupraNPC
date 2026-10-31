-- Integration: three zombies seen early, two unarmed => immediate retreat.
-- FLEE must keep walking active; threat gone restores FOLLOW.
package.path="42/media/lua/client/?.lua;42/media/lua/shared/?.lua;"..package.path
local time=10000
getTimestampMs=function() return time end
instanceof=function(o,t) return o and o.kind==t end
local zombieList={}
local cell={}
cell.getZombieList=function()
 return {size=function() return #zombieList end,
   get=function(_,i) return zombieList[i+1] end}
end
getCell=function() return cell end
local function makeHuman(x,y,weapon)
 return {kind="IsoPlayer",getX=function() return x end,getY=function() return y end,
    getZ=function() return 0 end,isDead=function() return false end,
    getForwardDirectionX=function() return 1 end,getForwardDirectionY=function() return 0 end,
    CanSee=function() return true end,getPrimaryHandItem=function() return weapon end}
end
local npc=makeHuman(0,0)
local player=makeHuman(1,0)
local md={SupraNPC_ID="A",SupraNPC_IsNPC=true}
npc.getModData=function() return md end
local weapon={kind="HandWeapon",isRanged=function() return false end,
 isBroken=function() return false end}
local function z(x,y)
 return {kind="IsoZombie",dead=false,
    isDead=function(self) return self.dead end,
    getX=function() return x end,getY=function() return y end,
    getZ=function() return 0 end,isOnFloor=function() return false end,
    isGettingUp=function() return false end}
end
local walking={started=0,cancelled=0,moving=false}
walking.active=function() return walking.moving end
walking.cancel=function() walking.moving=false;walking.cancelled=walking.cancelled+1 end
walking.start=function() walking.started=walking.started+1;walking.moving=true;return true end
walking.pickRetreat=function() return {} end
walking.pickAround=function() return {} end
walking.update=function() end
package.loaded["SupraNPC/NPCWalking"]=walking
package.loaded["SupraNPC/NPCNavigation"]={attackAccessible=function() return true end,next=function() return {},"waypoint" end,clear=function() end}

local Orders=require("SupraNPC/Orders")
local D=require("SupraNPC/NPCDefense")
local P=require("SupraNPC/NPCPerception")
local Speech=require("SupraNPC/NPCSpeech")
local entry={actor=npc,profile={id="A"},state=Orders.new("FOLLOW")}
zombieList={z(4,0),z(5,0),z(6,0)}
local initial=P.observe(npc,player,{})
assert(initial.standing==3 and initial.allies==1)
assert(P.risk(initial,100).retreat)
assert(D.update(entry,player,{})==true)
assert(entry.navStatus=="FLEE" and entry.state.active=="RETREAT")
assert(entry.state.requested=="FOLLOW")
assert(walking.started==1 and walking.moving)
assert(#Speech.active>=1) -- warning from NPC
for i=1,8 do
 time=time+600
 assert(D.update(entry,player,{})==true)
end
assert(walking.started==1 and walking.moving) -- do NOT cancel flee every tick
assert(walking.cancelled==0)
-- Losing sight of the group does not cancel a retreat already underway.
npc.getForwardDirectionX=function() return -1 end
time=time+650
assert(D.update(entry,player,{})==true)
assert(entry.navStatus=="FLEE" and entry.state.active=="RETREAT")
assert(walking.moving and walking.started==1)
for _,v in ipairs(zombieList) do v.dead=true end
time=time+2000
assert(D.update(entry,player,{})==false)
assert(entry.state.active=="FOLLOW")
assert(not walking.moving)
-- When both have proper melee, a group of 3 can be controlled.
npc.getPrimaryHandItem=function() return weapon end
player.getPrimaryHandItem=function() return weapon end
zombieList={z(4,0),z(5,0),z(6,0)}
npc.getForwardDirectionX=function() return 1 end
local armed=P.observe(npc,player,{})
assert(not P.risk(armed,100).retreat)
time=time+2000
assert(D.update(entry,player,{})==true)
assert(entry.state.active=="SELF_DEFEND")
assert(entry.navStatus=="APPROACH")
D.clear()
-- Stance must affect the interception distance, not only persistence.
zombieList={z(7,0)}
entry.stance="DEFENSIVE"
assert(D.update(entry,player,{})==false)
entry.stance="AGGRESSIVE"
time=time+2000
assert(D.update(entry,player,{})==true)
assert(entry.navStatus=="APPROACH")
D.clear()
-- Under lethal threat, return toward a player-marked base, not random wandering.
local Territory=require("SupraNPC/Territory")
local home=Territory.import({
  {text="NPC:BASE:A",x=20,y=20,z=0},
  {text="NPC:BASE:B",x=25,y=24,z=0}
})
player.getModData=function() return {SupraNPC_Territory=home} end
npc.getPrimaryHandItem=function() return nil end
player.getPrimaryHandItem=function() return nil end
walking.moving=false
zombieList={z(4,0),z(5,0),z(6,0)}
entry.stance="DEFENSIVE"
time=time+2000
assert(D.update(entry,player,{})==true)
assert(entry.state.active=="RETREAT")
assert(entry.navStatus=="FLEE_BASE")
assert(walking.moving)
D.clear()
Speech.clear()
print("[SupraNPC] risk_combat_spec: OK")
