package.path="42/media/lua/client/?.lua;42/media/lua/shared/?.lua;"..package.path
local M=require("SupraNPC/NPCMovementStyle")
local calls={}
local actor={
 getX=function() return 0 end,getY=function() return 0 end,
 getModData=function() return {SupraNPC_IsNPC=true,SupraNPC_ID="x"} end,
 setRunning=function(_,x) calls.running=x end,
 setSneaking=function(_,x) calls.sneaking=x end,
 setSprinting=function(_,x) calls.sprinting=x end
}
local player={getX=function() return 2 end,getY=function() return 0 end,
 isSneaking=function() return false end}
local e={actor=actor,profile={id="x"},navStatus="MOVING",
 state={active="FOLLOW"}}
assert(M.choose(e,player)=="WALK")
assert(M.apply(e,"WALK") and calls.running==false)
e.retreating=true
assert(M.update(e,player) and calls.running and not calls.sneaking and not calls.sprinting)
e.retreating=false
player.isSneaking=function() return true end
assert(M.update(e,player) and calls.sneaking and calls.running==false)
player.isSneaking=function() return false end
e.lastObservation={standing=1,nearStanding=0}
assert(M.choose(e,player)=="SNEAK")
e.lastObservation=nil
player.getX=function() return 10 end
assert(M.choose(e,player)=="RUN")
M.clear("x",actor)
assert(calls.running==false and calls.sneaking==false)
local bad={actor={getModData=function() return {SupraNPC_IsNPC=false} end},profile={id="x"}}
assert(not M.apply(bad,"RUN"))
print("[SupraNPC] movement_style_spec: OK")
