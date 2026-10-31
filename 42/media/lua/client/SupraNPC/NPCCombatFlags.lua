-- Runtime flags for SECONDARY IsoPlayer entities only.
-- No change to player-0; don't invent artificial hit point losses.
local Core=require("SupraNPC/Constants")
local F={}
local function call(actor,method,...)
 if not actor then return nil end
 local args={...}
 local ok,val=pcall(function()
    if actor[method] then return actor[method](actor,unpack(args)) end
 end)
 if ok then return val end
end
local function owned(actor,id)
 local md=call(actor,"getModData")
 return md and md.SupraNPC_IsNPC==true and md.SupraNPC_ID==id
end
function F.configure(actor,id)
 if not id or not owned(actor,id) then return false,"not owned npc" end
 -- In B42 the spelling is setNpc(), not setNPC(). The old call to
 -- setNPC silently failed behind pcall. Also explicitly remove cheat
 -- flags on newly constructed / reattached secondary IsoPlayers.
 call(actor,"setNpc",true)
 call(actor,"setGodMod",false)
 call(actor,"setInvulnerable",false)
 call(actor,"setInvincible",false)
 call(actor,"setHealthCheat",false)
 call(actor,"setZombiesDontAttack",false)
 call(actor,"setGhostMode",false)
 call(actor,"setInvisible",false)
 local god=call(actor,"isGodMod")
 local invulnerable=call(actor,"isInvulnerable")
 local ignored=call(actor,"isZombiesDontAttack")
 Core.log("NPC_FLAGS "..id..
     " isNpc="..tostring(call(actor,"isNpc"))..
     " god="..tostring(god)..
     " invulnerable="..tostring(invulnerable)..
     " zombiesDontAttack="..tostring(ignored))
 if god==true or invulnerable==true or ignored==true then
    return false,"native invulnerability persists"
 end
 return true
end
return F
