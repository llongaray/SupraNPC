package.path="42/media/lua/shared/?.lua;"..package.path
local T=require("SupraNPC/CombatTactics")
local function decide(s,standing,down,ally,d,dd,opts)
 opts=opts or {}
 return T.plan(s,{standing=standing,down=down,ally=ally,
    nearestDistance=d,nearestDownDistance=dd,
    visible=opts.visible~=false,downVisible=true,
    mustRetreat=opts.retreat==true,
    alertStanding=opts.alertStanding,
    alertDistance=opts.alertDistance})
end
local s=T.new()
assert(decide(s,1,0,false,1.0,nil)=="SHOVE")
assert(decide(s,1,0,false,1.0,nil)=="SHOVE") -- persist until actual fall
assert(decide(s,1,0,false,1.0,nil)=="SHOVE")
s.failedShoves=4
assert(decide(s,1,0,false,0.6,nil)=="BACKSTEP")
assert(decide(s,1,0,false,2.5,nil)=="WAIT")
assert(decide(s,0,1,false,nil,1.5)=="PIN")
assert(decide(s,0,1,false,nil,0.7)=="STOMP")
assert(decide(s,0,0,false)=="RESUME")
-- three zombies, weak solo: early retreat and persistent flee
s=T.new()
assert(decide(s,0,0,false,nil,nil,{retreat=true,alertStanding=3,alertDistance=9})=="FLEE")
assert(decide(s,3,0,false,0.75,nil,{retreat=true})=="SHOVE")
assert(decide(s,3,0,false,1.2,nil,{retreat=true})=="FLEE")
assert(decide(s,0,2,false,nil,0.7,{retreat=true})=="FLEE")
assert(decide(s,0,0,false)=="RESUME")
-- three zombies with armed support: keep them on feet controlled
s=T.new()
assert(decide(s,3,0,true,1.0,nil)=="SHOVE")
assert(decide(s,3,0,true,1.0,nil)=="BACKSTEP")
assert(decide(s,3,0,true,2,nil)=="WAIT")
assert(decide(s,3,0,true,1.0,nil)=="SHOVE")
assert(decide(s,2,1,true,1.1,0.7)=="BACKSTEP")
for i=1,5 do
 local a=decide(s,1,1,true,1.0,0.5)
 assert(a~="STOMP" and a~="PIN")
end
assert(decide(s,0,2,true,nil,0.7)=="STOMP")
-- vision-based intercept instead of waiting for first hit.
s=T.new()
assert(decide(s,0,0,false,nil,nil,{alertStanding=1,alertDistance=7})=="APPROACH")
assert(decide(s,0,0,false,nil,nil,{alertStanding=1,alertDistance=11})=="WATCH")
assert(T.plan(s,{standing=-1,down=0})==nil)
print("[SupraNPC] combat_tactics_spec: OK")
