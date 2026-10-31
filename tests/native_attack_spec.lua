package.path="42/media/lua/client/?.lua;42/media/lua/shared/?.lua;"..package.path
instanceof=function(o,t) return o and o.kind==t end
local A=require("SupraNPC/NPCNativeAttack")
local target={kind="IsoZombie",x=1,y=0,down=false,dead=false}
function target:getX() return self.x end
function target:getY() return self.y end
function target:getZ() return 0 end
function target:isDead() return self.dead end
function target:isOnFloor() return self.down end
function target:isProne() return self.down end
function target:isGettingUp() return false end
function target:isCrawling() return false end
local w={kind="HandWeapon",isBroken=function() return false end,
 isRanged=function() return false end,isAimedFirearm=function() return false end}
local actor={kind="IsoPlayer",x=0,y=0,shove=false,attacks={}}
function actor:getX() return self.x end
function actor:getY() return self.y end
function actor:getZ() return 0 end
function actor:isDead() return false end
function actor:getPrimaryHandItem() return w end
function actor:CanSee(z) return not z.blocked end
function actor:getModData() return {SupraNPC_IsNPC=true} end
function actor:faceThisObject() end
function actor:setDoShove(v) self.shove=v end
function actor:setAuthorizedHandToHandAction(v) self.authorizedAction=v end
function actor:setAuthorizedHandToHand(v) self.authorizedMelee=v end
function actor:DoAttack(charge)
  assert(charge==1)
  self.attacks[#self.attacks+1]=self.shove and "SHOVE" or "NORMAL"
  return true
end
assert(A.choose(actor,target)=="SHOVE")
assert(A.execute(actor,target,"SHOVE"))
assert(actor.authorizedAction==true and actor.authorizedMelee==true)
assert(actor.attacks[1]=="SHOVE" and actor.shove==false)
target.x=1.6
assert(A.choose(actor,target)=="SWING")
assert(A.execute(actor,target,"SWING"))
assert(actor.attacks[2]=="NORMAL")
target.x=1.0;target.down=true
assert(A.choose(actor,target)=="GROUND")
assert(A.execute(actor,target,"GROUND"))
assert(actor.attacks[3]=="NORMAL")
local player={getX=function() return 0.5 end,getY=function() return 0 end,
 getZ=function() return 0 end,isDead=function() return false end}
assert(A.execute(actor,target,"GROUND",player)==false)
assert(#actor.attacks==3)
target.blocked=true
assert(A.execute(actor,target,"GROUND")==false)
target.blocked=false
target.kind="IsoPlayer"
assert(A.execute(actor,target,"GROUND")==false)
assert(#actor.attacks==3)
print("[SupraNPC] native_attack_spec: OK")
