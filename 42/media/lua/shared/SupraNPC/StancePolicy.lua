-- SupraNPC: explicit stance policy. Pure Lua 5.1, no game API calls.
-- Stance changes combat priorities, not only the detection radius.
local S={}
S.VALID={PASSIVE=true,DEFENSIVE=true,AGGRESSIVE=true}
local ranges={PASSIVE=9.0,DEFENSIVE=5.5,AGGRESSIVE=12.0}
local function number(n) return type(n)=="number" and n==n end
function S.decide(stance,obs,health,risk,memory)
 stance=S.VALID[stance] and stance or "DEFENSIVE"
 obs=type(obs)=="table" and obs or {}
 risk=type(risk)=="table" and risk or {}
 local seen=number(obs.alertDistance) and obs.alertDistance<=ranges[stance]
 local near=number(obs.nearStanding) and obs.nearStanding or 0
 local group=number(obs.standing) and obs.standing or near
 local critical=number(health) and health<35
 local retreat=false
 if stance=="PASSIVE" then
    -- Never attack, shove, pin or finish enemies. One visible zombie is enough.
    retreat=seen or memory==true
 elseif stance=="DEFENSIVE" then
    -- Fighting is preferred against 1 or 2; retreat when overwhelmed
    -- (3+ without melee support, 4+ outnumbered, or critically wounded).
    local unarmed=obs.npcWeapon and obs.npcWeapon.category~="MELEE" and
       (obs.armed or 0)==0
    local enemies=math.max(near,group>=3 and
       (number(obs.alertDistance) and obs.alertDistance<=9 and group or 0) or 0)
    local power=number(obs.groupPower) and obs.groupPower or 0.8
    retreat=(enemies>=3 and (unarmed or enemies>=4 and
       power<enemies*1.1)) or (critical and enemies>=1)
    -- Retain a short existing escape if threat was just lost from vision.
    retreat=retreat or memory==true
 else
    -- Aggressive: pursuit and killing outrank self-preservation and
    -- all manually requested work. Obstacle/ally safety still applies.
    retreat=false
 end
 return {stance=stance,engage=seen or (memory==true and stance~="AGGRESSIVE"),
   retreat=retreat,range=ranges[stance]}
end
return S
