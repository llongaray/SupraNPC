-- Stance decisions independent of the game's Java classes (Lua 5.1).
package.path="42/media/lua/shared/?.lua;"..package.path
local S=require("SupraNPC/StancePolicy")
local function enemies(n,d,weapon,groupPower)
 return {standing=n,nearStanding=n,seen=n,alertDistance=d,
   npcWeapon={category=weapon or "UNARMED"},armed=0,
   groupPower=groupPower or 0.8}
end
-- PASSIVE: even one zombie causes retreat, despite being armed.
local one=enemies(1,5,"MELEE",2)
local passive=S.decide("PASSIVE",one,100,{retreat=false},false)
assert(passive.engage and passive.retreat and passive.range==9)
assert(S.decide("PASSIVE",enemies(1,10),100,{},false).engage==false)
assert(S.decide("PASSIVE",enemies(0,nil),100,{},true).retreat)
-- DEFENSIVE: standing ground is normal, retreat only when overwhelmed.
local defend=S.decide("DEFENSIVE",enemies(1,3),100,{},false)
assert(defend.engage and not defend.retreat)
assert(not S.decide("DEFENSIVE",enemies(2,3),100,{},false).retreat)
assert(S.decide("DEFENSIVE",enemies(3,3),100,{},false).retreat)
assert(not S.decide("DEFENSIVE",enemies(3,3,"MELEE",8),100,{},false).retreat)
assert(S.decide("DEFENSIVE",enemies(2,3),20,{},false).retreat)
-- AGGRESSIVE: continue fighting outnumbered, even without weapons.
local aggressive=S.decide("AGGRESSIVE",enemies(7,9),10,{retreat=true},false)
assert(aggressive.engage and not aggressive.retreat and aggressive.range==12)
assert(S.decide("AGGRESSIVE",enemies(1,11.7),100,{},false).engage)
assert(not S.decide("AGGRESSIVE",enemies(1,12.5),100,{},false).engage)
assert(S.decide("unknown",one,100,{},false).stance=="DEFENSIVE")
print("[SupraNPC] stance_policy_spec: OK")
