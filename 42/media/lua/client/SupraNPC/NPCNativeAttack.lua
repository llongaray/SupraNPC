-- Build 42 native melee input for IsoPlayer-backed NPCs.
-- No direct damage here: the engine chooses swing, shove or ground attack.
local Core=require("SupraNPC/Constants")
local Perception=require("SupraNPC/NPCPerception")
local Navigation=require("SupraNPC/NPCNavigation")
local A={CLOSE=1.02,MELEE_REACH=1.85,GROUND_REACH=1.35}
local function get(o,k,...)
 if not o then return nil end
 local args={...}
 local ok,r=pcall(function()
   if o[k] then return o[k](o,unpack(args)) end
 end)
 if ok then return r end
end
local function dist(a,b)
 local x,y,z=get(a,"getX"),get(a,"getY"),get(a,"getZ")
 local u,v,w=get(b,"getX"),get(b,"getY"),get(b,"getZ")
 if type(x)~="number" or type(y)~="number" or type(z)~="number" or
    type(u)~="number" or type(v)~="number" or type(w)~="number" or
    math.floor(z)~=math.floor(w) then return nil end
 return math.sqrt((x-u)^2+(y-v)^2),u-x,v-y
end
A.distance=dist
local function isZombie(z)
 if not z or not instanceof then return false end
 local ok,yes=pcall(instanceof,z,"IsoZombie")
 return ok and yes==true and get(z,"isDead")==false
end
local function otherAllyInArc(actor,target,player,team)
 local d,tx,ty=dist(actor,target)
 if not d or d<0.1 then return false end
 local checked={}
 local function dangerous(ally)
   if not ally or ally==actor or checked[ally] or get(ally,"isDead")~=false then
      return false end
   checked[ally]=true
   local ad,dx,dy=dist(actor,ally)
   if not ad or ad>=d+0.35 or ad>2.1 or ad<0.15 then return false end
   local cos=(dx*tx+dy*ty)/(ad*d)
   return cos>0.90
 end
 if dangerous(player) then return true end
 if type(team)=="table" then
   for _,e in pairs(team) do
      if type(e)=="table" and dangerous(e.actor) then return true end
   end
 end
 return false
end
function A.choose(actor,target)
 if not isZombie(target) then return nil,"invalid zombie" end
 local d=dist(actor,target)
 if not d then return nil,"invalid distance" end
 local floor=get(target,"isOnFloor")==true or get(target,"isProne")==true
 floor=floor and get(target,"isGettingUp")~=true and get(target,"isCrawling")~=true
 if floor then return d<=A.GROUND_REACH and "GROUND" or "APPROACH",d end
 local weapon=get(actor,"getPrimaryHandItem")
 local melee=false
 if weapon and instanceof then
   local ok,hand=pcall(instanceof,weapon,"HandWeapon")
   if ok and hand and get(weapon,"isBroken")~=true and
      get(weapon,"isRanged")~=true and
      get(weapon,"isAimedFirearm")~=true then melee=true end
 end
 if d<=A.CLOSE then return "SHOVE",d end
 if melee and d<=A.MELEE_REACH then return "SWING",d end
 if not melee and d<=1.42 then return "SHOVE",d end
 return "APPROACH",d
end
function A.execute(actor,target,kind,player,team)
 if not actor or get(actor,"isDead")~=false or not isZombie(target) then
    return false,"invalid actor/zombie" end
 if type(kind)~="string" or
    (kind~="SHOVE" and kind~="SWING" and kind~="GROUND") then
    return false,"invalid melee action" end
 local md=get(actor,"getModData")
 if not md or md.SupraNPC_IsNPC~=true then return false,"not an owned NPC" end
 local chosen,d=A.choose(actor,target)
 if not d or (kind=="GROUND" and chosen~="GROUND") or
    (kind=="SHOVE" and d>1.42) or (kind=="SWING" and d>A.MELEE_REACH) then
    return false,"out of reach" end
 if not Perception.clearAdjacent(actor,target) then return false,"target occluded" end
 if getCell and not Navigation.attackAccessible(actor,target) then
    return false,"impassable door/window between NPC and zombie" end
 if otherAllyInArc(actor,target,player,team) then
    return false,"ally in swing arc" end
 if get(actor,"isAttacking")==true or get(actor,"isAttackStarted")==true then
    return false,"attack animation running" end
 if type(actor.DoAttack)~="function" and not actor.DoAttack then
    return false,"IsoPlayer.DoAttack unavailable" end
 local ok,reason=pcall(function()
    if actor.faceThisObject then actor:faceThisObject(target) end
    -- B42 distinguishes permission to initiate a hand-to-hand action from
    -- permission to perform it. Extra IsoPlayer entities may be missing
    -- either permission. Enable only on the owned NPC before native attack.
    if actor.setAuthorizedHandToHandAction then
        actor:setAuthorizedHandToHandAction(true)
    end
    if actor.setAuthorizedHandToHand then
        actor:setAuthorizedHandToHand(true)
    end
    if actor.setAuthorizeShoveStomp then
        pcall(function() actor:setAuthorizeShoveStomp(true) end)
    end
    if actor.setAuthorizeMeleeAction then
        pcall(function() actor:setAuthorizeMeleeAction(true) end)
    end
    -- Short range/ground use normal attack selection. For a close standing
    -- zombie, request shove explicitly; do not simulate knockDown().
    if actor.setDoShove then actor:setDoShove(kind=="SHOVE") end
    return actor:DoAttack(1.0)
 end)
 -- Reset forceShove so the next weapon swing/ground strike uses vanilla
 -- range logic. No artificial zombie health modifications.
 -- Keep shove intent until the engine consumes it. Resetting in the
 -- same Lua call caused the native animation to read shove=false.
 -- It is cleared on the next normal swing or after combat ends.
 if not ok or reason~=true then
    if actor.setDoShove then pcall(function() actor:setDoShove(false) end) end
 end
 if not ok then return false,"DoAttack error: "..tostring(reason) end
 if reason~=true then return false,"DoAttack rejected: "..tostring(reason) end
 -- Detailed per-tick combat feedback is aggregated in NPCDefense.pulse;
 -- avoid generating hundreds of identical log lines per fight.
 return true,"native attack requested"
end
function A.release(actor)
 if actor and actor.setDoShove then
    pcall(function() actor:setDoShove(false) end)
 end
end
return A
