-- Perception B42: FOV funnel, wall occlusion, near awareness and equipment.
package.path="42/media/lua/client/?.lua;42/media/lua/shared/?.lua;"..package.path
instanceof=function(o,t) return o and o.kind==t end
local P=require("SupraNPC/NPCPerception")
local function actor(x,y,weapon)
 return {
    kind="IsoPlayer",
    getX=function() return x end,
    getY=function() return y end,
    getZ=function() return 0 end,
    isDead=function() return false end,
    CanSee=function(self,z) return not z.blocked end,
    getForwardDirectionX=function() return 1 end,
    getForwardDirectionY=function() return 0 end,
    getPrimaryHandItem=function() return weapon end
 }
end
local function weapon(ranged)
 return {kind="HandWeapon",
    isRanged=function() return ranged end,
    getCurrentAmmoCount=function() return 4 end,
    isBroken=function() return false end
 }
end
local p=actor(0,0)
local function z(x,y,down)
 return {kind="IsoZombie",
    getX=function() return x end,
    getY=function() return y end,
    getZ=function() return 0 end,
    isDead=function() return false end,
    isOnFloor=function() return down==true end,
    isProne=function() return down==true end,
    isGettingUp=function() return false end}
end
assert(P.equipment(p).category=="UNARMED")
assert(P.equipment(actor(0,0,weapon(false))).category=="MELEE")
assert(P.equipment(actor(0,0,weapon(true))).category=="FIREARM")
assert(P.canPerceive(p,z(9,0),9,9,0))
assert(not P.canPerceive(p,z(-9,0),9,-9,0))
assert(P.canPerceive(p,z(-2,0),2,-2,0))
local blocked=z(7,0);blocked.blocked=true
assert(not P.canPerceive(p,blocked,7,7,0))
local zombies={z(5,0),z(6,1),z(8,-1),z(-9,0)}
getCell=function() return {getZombieList=function()
  return {size=function() return #zombies end,
      get=function(_,i) return zombies[i+1] end}
 end} end
local ally=actor(1,0)
local o=P.observe(p,ally,{})
assert(o.standing==3 and o.seen==3)
assert(o.allies==1 and o.unarmed==1 and o.armed==0)
assert(o.nearStanding==1 and o.alertDistance<=5)
local risk=P.risk(o,100)
assert(risk.retreat and risk.unarmed)
local actorMelee=actor(0,0,weapon(false))
local allyMelee=actor(1,0,weapon(false))
local stronger=P.observe(actorMelee,allyMelee,{})
assert(stronger.armed==1 and stronger.groupPower==4)
assert(P.risk(stronger,100).retreat==false)
assert(P.risk(stronger,30).retreat==true)
-- Defend a player under attack unless this NPC is in immediate danger.
local distantAssailant=z(3.8,0)
zombies={z(2.3,0),distantAssailant}
local rescuing=P.observe(p,actor(3.8,0.5),{})
assert(rescuing.urgentTarget==distantAssailant)
assert(rescuing.nearest==distantAssailant)
zombies={z(1.0,0),distantAssailant}
local selfDefense=P.observe(p,actor(3.8,0.5),{})
assert(selfDefense.urgentTarget==distantAssailant)
assert(selfDefense.nearestDistance==1.0) -- self protection has precedence
-- Secondary IsoPlayers may have an empty CanSee cache. LOS from the
-- map must still notice zombies at 7 tiles, but never through a wall.
local extra=actor(0,0)
extra.CanSee=function() return false end
extra.getCurrentSquare=function() return {} end
local far=z(7,0)
far.getCurrentSquare=function() return {} end
local losCell={}
getCell=function() return losCell end
local actualLOS="Clear"
LosUtil={lineClear=function(c,x1,y1,z1,x2,y2,z2,ignoreDoors)
    assert(c==losCell and ignoreDoors==false)
    return actualLOS
end}
assert(P.canPerceive(extra,far,7,7,0))
actualLOS="Blocked"
assert(not P.canPerceive(extra,far,7,7,0))
actualLOS="ClearThroughClosedDoor"
assert(not P.canPerceive(extra,far,7,7,0))
actualLOS="ClearThroughOpenDoor"
assert(P.canPerceive(extra,far,7,7,0))
LosUtil=nil
assert(not P.canPerceive(extra,far,7,7,0))
print("[SupraNPC] perception_spec: OK")
