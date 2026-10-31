package.path="42/media/lua/shared/?.lua;"..package.path
local T=require("SupraNPC/CombatTactics")
local function decide(s,standing,down,ally,d,dd,visible)
    return T.plan(s,{standing=standing,down=down,ally=ally,
        nearestDistance=d,nearestDownDistance=dd,
        visible=visible~=false,downVisible=true})
end
local s=T.new()
assert(decide(s,1,0,false,1.0,nil)=="SHOVE")
assert(decide(s,1,0,false,1.0,nil)=="BACKSTEP")
assert(decide(s,1,0,false,1.0,nil)=="WAIT")
assert(decide(s,1,0,false,2.5,nil)=="WAIT") -- nunca persegue apos recuar
assert(decide(s,0,1,false,nil,1.2)=="PIN")
assert(decide(s,0,1,false,nil,0.7)=="STOMP")
assert(decide(s,0,0,false)=="RESUME")
-- Solo: empurra o grupo grande e escapa, mesmo apos um zumbi cair.
s=T.new()
assert(decide(s,3,0,false,1.1,nil)=="SHOVE")
assert(decide(s,2,1,false,1.2,1.1)=="FLEE")
assert(s.escape==true)
assert(decide(s,0,2,false,nil,0.5)=="FLEE")
assert(decide(s,0,0,false)=="RESUME")
-- Ajuda do player conta como suporte, entao alterna shove/recuo.
s=T.new()
assert(decide(s,3,0,true,1.0,nil)=="SHOVE")
assert(decide(s,3,0,true,1.0,nil)=="BACKSTEP")
assert(decide(s,3,0,true,1.0,nil)=="WAIT")
assert(decide(s,3,0,true,1.0,nil)=="SHOVE")
assert(decide(s,2,1,true,1.2,0.7)=="BACKSTEP")
-- O primeiro caido NAO deve ser golpeado enquanto houver outro em pe.
for _=1,5 do
    local action=decide(s,1,1,true,1.0,0.5)
    assert(action~="STOMP" and action~="PIN")
end
assert(decide(s,0,2,true,nil,0.7)=="STOMP")
assert(T.plan(s,{standing=-1,down=0})==nil)
print("[SupraNPC] combat_tactics_spec: OK")
