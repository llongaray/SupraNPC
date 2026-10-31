-- SupraNPC tactical planner, pure Lua 5.1. No engine calls.
-- Never assume a shove succeeded; the observed down state decides.
local T={SHOVE_RANGE=1.32, STOMP_RANGE=1.35, DANGER_RADIUS=6}
local function good(n) return type(n)=="number" and n==n and n>=0 end
function T.new()
 return {last="NONE",cycles=0,failedShoves=0,escape=false,wasThreatened=false}
end
function T.plan(state,o)
 if type(state)~="table" or type(o)~="table" then return nil,"invalid" end
 local standing=o.standing or 0;local down=o.down or 0
 if not good(standing) or not good(down) or
    standing%1~=0 or down%1~=0 then return nil,"invalid_counts" end
 local stance=o.stance or "DEFENSIVE"
 if stance=="PASSIVE" then
    -- Absolute rule: no shove, stomp, swing or pursuit in passive posture.
    state.groupCombat=false
    state.escape=o.mustRetreat==true
    state.last=state.escape and "FLEE" or "RESUME"
    return state.last,state.escape and "PASSIVE_ESCAPE" or "PASSIVE_CLEAR"
 end
 if stance=="AGGRESSIVE" or o.mustRetreat~=true then
    -- A posture switch or improved circumstances must not inherit an old
    -- FLEE loop from the previous combat plan.
    state.escape=false
 end
 local action,tactic="WATCH","AWARE"
 local nearby=standing+down
 if standing>=3 then state.groupCombat=true end
 if standing==0 then state.groupCombat=false end
 local distant=o.alertStanding or standing
 local dist=o.nearestDistance
 if nearby==0 then
    if o.mustRetreat then
       action,tactic="FLEE","DANGER"
       state.escape=true
    elseif distant==0 then
       action,tactic="RESUME","NONE"
       state.escape=false;state.failedShoves=0
    elseif good(o.alertDistance) and
           o.alertDistance<=(o.engageRange or 8) then
       action,tactic="APPROACH","INTERCEPT"
    end
 elseif o.mustRetreat or state.escape then
    state.escape=true
    tactic="ESCAPE"
    if standing>0 and good(dist) and dist<=0.95 and
       state.last~="SHOVE" then
       action="SHOVE" -- one emergency push to create space
    else action="FLEE" end
 elseif standing>=3 or state.groupCombat then
    tactic="SUPPORTED"
    if state.last=="SHOVE" then action="BACKSTEP"
    elseif state.last=="BACKSTEP" and good(dist) and dist>T.SHOVE_RANGE then
       action="WAIT"
    elseif good(dist) and dist<=T.SHOVE_RANGE and o.visible then
       action="SHOVE"
    elseif good(dist) and o.melee==true and dist<=1.85 then action="SWING"
    elseif good(dist) and dist<=math.max(5.5,o.engageRange or 5.5) then action="APPROACH"
    else action="WAIT" end
 elseif standing>0 then
    tactic="SUSTAINED_SHOVE"
    if state.last=="BACKSTEP" and good(dist) and dist>T.SHOVE_RANGE then
       action="WAIT"
    elseif good(dist) and dist<=1.02 and o.visible then
       if (state.failedShoves or 0)>=4 and dist<0.8 then
          action="BACKSTEP";state.failedShoves=0
       else action="SHOVE" end
    elseif good(dist) and o.melee==true and dist<=1.85 and o.visible then
       action="SWING"
    elseif good(dist) and dist<=T.SHOVE_RANGE and o.visible then
       action="SHOVE"
    elseif good(dist) and dist<=(o.engageRange or 8) then
       action="APPROACH"
    else action="WATCH" end
 elseif down>0 then
    tactic="FINISH_DOWNED"
    local d=o.nearestDownDistance
    if not good(d) then action="WAIT"
    elseif d>T.STOMP_RANGE then action="PIN"
    elseif o.downVisible==true then action="STOMP"
    else action="WAIT" end
 end
 if action=="SHOVE" then state.cycles=(state.cycles or 0)+1 end
 state.last=action
 return action,tactic
end
return T
