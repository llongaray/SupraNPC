-- Planner tatico puro (Lua 5.1). Nao altera entidades nem simula quedas.
-- A acao seguinte sempre depende do estado OBSERVADO dos zumbis.
local T = {}
T.SHOVE_RANGE = 1.32
T.STOMP_RANGE = 0.92
T.DANGER_RADIUS = 4.0

local function valid(v)
    return type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge
end
function T.new()
    return {last="NONE", tactic="NONE", cycles=0}
end
-- input: standing, down, ally, nearestDistance, nearestDownDistance, visible
-- output: SHOVE, BACKSTEP, FLEE, APPROACH, PIN, STOMP, RESUME, WAIT
function T.plan(state, input)
    if type(state)~="table" or type(input)~="table" then return nil,"invalid_state" end
    local standing, down = input.standing, input.down
    if not valid(standing) or not valid(down) or
       standing<0 or down<0 or standing%1~=0 or down%1~=0 then
        return nil,"invalid_counts"
    end
    local action,tactic
    if standing==0 and down==0 then
        action,tactic="RESUME","NONE"
    elseif standing==0 then
        tactic="FINISH_DOWNED"
        local dist=input.nearestDownDistance
        if not valid(dist) then action="WAIT"
        elseif dist>T.STOMP_RANGE then action="PIN"
        elseif input.downVisible==true then action="STOMP"
        else action="WAIT" end
    else
        local d=input.nearestDistance
        local visible=input.visible==true
        if standing>=3 and input.ally~=true then
            tactic="SOLO_ESCAPE"
            -- Empurrar uma vez ao alcance, depois fugir. Se nao der:
            -- fugir imediatamente (nunca atacar trio sem apoio).
            if visible and valid(d) and d<=T.SHOVE_RANGE and
               state.last~="SHOVE" and state.last~="FLEE" then
                action="SHOVE"
            else action="FLEE" end
        elseif standing>=3 then
            tactic="SUPPORTED_CONTROL"
            if state.last=="SHOVE" then
                action="BACKSTEP"
            elseif valid(d) and d<=T.SHOVE_RANGE and visible then
                action="SHOVE"
            elseif state.last=="BACKSTEP" or not visible then
                action="WAIT" -- deixa os zumbis se aproximarem
            else action="APPROACH" end
        else
            tactic="SINGLE_CONTROL"
            if state.last=="SHOVE" then
                action="BACKSTEP"
            elseif not visible then
                action="WAIT"
            elseif valid(d) and d<=T.SHOVE_RANGE then
                action="SHOVE"
            elseif state.last=="BACKSTEP" then
                action="WAIT"
            else action="APPROACH" end
        end
    end
    if action=="SHOVE" then state.cycles=(state.cycles or 0)+1 end
    state.last,state.tactic=action,tactic
    return action,tactic
end
return T
