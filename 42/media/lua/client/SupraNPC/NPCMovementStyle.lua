-- IsoPlayer locomotion postures: walk, sneak, run. No teleports or speed hacks.
local Core=require("SupraNPC/Constants")
local M={last={}}
local function call(obj,key,...)
 if not obj then return nil end
 local args={...};local ok,r=pcall(function()
   if obj[key] then return obj[key](obj,unpack(args)) end end)
 if ok then return r end
end
local function distance(a,b)
 local x,y=call(a,"getX"),call(a,"getY")
 local u,v=call(b,"getX"),call(b,"getY")
 if type(x)~="number" or type(y)~="number" or
    type(u)~="number" or type(v)~="number" then return nil end
 return math.sqrt((x-u)^2+(y-v)^2)
end
function M.choose(entry,player)
 if not entry then return "WALK" end
 local status=entry.navStatus or ""
 if status=="CLIMB_WINDOW" then return "WALK" end
 local obs=entry.lastObservation
 if entry.retreating or status=="FLEE" or status=="RETURN_BASE" then
   return "RUN"
 end
 if status=="SHOVE" or status=="SWING" or status=="STOMP" or
     status=="DEFENDING" then return "WALK" end
 if call(player,"isSneaking")==true then return "SNEAK" end
 if obs and obs.standing and obs.standing>0 and
     not (obs.nearStanding and obs.nearStanding>0) then
    return "SNEAK"
 end
 local gap=distance(entry.actor,player)
 if entry.state and entry.state.active=="FOLLOW" and gap and gap>5.5 then
    return "RUN"
 end
 return "WALK"
end
function M.apply(entry,mode)
 if not entry or not entry.actor or not entry.profile then return false end
 local actor=entry.actor
 local md=call(actor,"getModData")
 if not md or md.SupraNPC_IsNPC~=true or
     md.SupraNPC_ID~=entry.profile.id then return false end
 if mode~="RUN" and mode~="SNEAK" then mode="WALK" end
 if M.last[entry.profile.id]==mode then return true end
 local ok=pcall(function()
    if actor.setSprinting then actor:setSprinting(false) end
    if actor.setSneaking then actor:setSneaking(mode=="SNEAK") end
    if actor.setRunning then actor:setRunning(mode=="RUN") end
 end)
 if ok then
   M.last[entry.profile.id]=mode
   entry.movementMode=mode
   Core.log("MOVEMENT "..entry.profile.id.." "..mode)
 end
 return ok
end
function M.update(entry,player)
 return M.apply(entry,M.choose(entry,player))
end
function M.clear(id,actor)
 if actor then pcall(function()
   if actor.setSprinting then actor:setSprinting(false) end
   if actor.setRunning then actor:setRunning(false) end
   if actor.setSneaking then actor:setSneaking(false) end
 end) end
 M.last[id]=nil
end
return M
