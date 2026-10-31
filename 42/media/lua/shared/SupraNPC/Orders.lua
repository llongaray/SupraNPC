-- Máquina de ordens totalmente determinística. Sem LLM, RN ou RL.
local Core = require("SupraNPC/Constants")
local Orders = {}
Orders.VALID = {
    IDLE = true, FOLLOW = true, GUARD = true, SELF_DEFEND = true,
    PROTECT = true, LOOT = true, EQUIP = true, CRAFT = true,
    EAT = true, DRINK = true, HEAL = true, RETURN_BASE = true
}
Orders.DEFAULT = "FOLLOW"

function Orders.new(initial)
    local command = Orders.VALID[initial] and initial or Orders.DEFAULT
    return { requested = command, active = command, interrupted = nil }
end

function Orders.set(state, requested)
    if type(state) ~= "table" or not Orders.VALID[requested] then
        return false, "ordem desconhecida"
    end
    state.requested = requested
    if state.active ~= "SELF_DEFEND" then state.active = requested end
    return true
end

function Orders.threat(state, threatened)
    if type(state) ~= "table" then return false end
    if threatened and state.active ~= "SELF_DEFEND" then
        state.interrupted = state.active
        state.active = "SELF_DEFEND"
    elseif not threatened and state.active == "SELF_DEFEND" then
        state.active = state.requested or state.interrupted or Orders.DEFAULT
        state.interrupted = nil
    end
    return true
end

Core.Orders = Orders
return Orders
