-- Close-quarters combat must keep pressure without repeated world scans.
package.path="42/media/lua/client/?.lua;42/media/lua/shared/?.lua;"..package.path
local ms=1000
getTimestampMs=function() return ms end
instanceof=function(o,kind) return o and o.kind==kind end
local calls=0
local walks=0
local moving=true
package.loaded["SupraNPC/NPCWalking"]={
 active=function() return moving end,
 cancel=function() moving=false;walks=walks+1 end
}
package.loaded["SupraNPC/NPCNavigation"]={
 isClimbing=function() return false end
}
package.loaded["SupraNPC/NPCNativeAttack"]={
 choose=function(_,z)
    if z.dead then return nil end
    return z.down and "GROUND" or "SHOVE",1.1
 end,
 execute=function(_,z,kind)
    assert(not z.dead and kind=="SHOVE" or z.down and kind=="GROUND")
    calls=calls+1
    return true,"native attack requested"
 end
}
local D=require("SupraNPC/NPCDefense")
local npc={DoAttack=function() return true end,isDead=function() return false end}
local z={kind="IsoZombie",dead=false,isDead=function(self) return self.dead end}
local entry={profile={id="npc1"},actor=npc,stance="AGGRESSIVE",
    retreating=false,state={active="SELF_DEFEND"},
    lastObservation={nearStanding=1}}
D.STATES.npc1={entry=entry,target=z}
assert(D.pulse(entry,{}, {})==true)
assert(calls==1 and walks==1 and not moving)
assert(entry.navStatus=="SHOVE")
ms=1100
assert(D.pulse(entry,{}, {})==false and calls==1)
ms=1260
assert(D.pulse(entry,{}, {})==true and calls==2)
z.dead=true
ms=1600
assert(D.pulse(entry,{}, {})==false and calls==2)
z.dead=false
entry.stance="PASSIVE"
assert(D.pulse(entry,{}, {})==false and calls==2)
entry.stance="AGGRESSIVE"
entry.retreating=true
assert(D.pulse(entry,{}, {})==false and calls==2)
entry.retreating=false
entry.lastObservation.nearStanding=2
z.down=true
assert(D.pulse(entry,{}, {})==false and calls==2)
entry.lastObservation.nearStanding=0
assert(D.pulse(entry,{}, {})==true and calls==3 and entry.navStatus=="STOMP")
D.clear()
print("[SupraNPC] aggressive_pulse_spec: OK")
