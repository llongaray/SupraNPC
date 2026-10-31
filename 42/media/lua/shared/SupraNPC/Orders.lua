-- SupraNPC - controlador deterministico de ordens (puro Lua 5.1).
-- Define decisoes. NAO move entidades, ataca ou acessa APIs do PZ.
-- Chamadas legadas Orders.new/set/threat mantidas compativeis.
local Core = require("SupraNPC/Constants")
local Orders = {}

Orders.VALID = {
    IDLE = true, FOLLOW = true, GUARD = true, SELF_DEFEND = true,
    PROTECT = true, LOOT = true, EQUIP = true, CRAFT = true,
    EAT = true, DRINK = true, HEAL = true, RETURN_BASE = true,
    ATTACK = true, RETREAT = true, MISSION = true
}
Orders.DEFAULT = "FOLLOW"
Orders.EXECUTABLE_REQUESTS = {
    IDLE = true, FOLLOW = true, GUARD = true, LOOT = true,
    EQUIP = true, CRAFT = true, EAT = true, DRINK = true,
    HEAL = true, RETURN_BASE = true, ATTACK = true, MISSION = true
}

local function finite(value)
    return type(value) == "number" and value == value and
        value ~= math.huge and value ~= -math.huge
end

local function position(x, y, z)
    if not finite(x) or not finite(y) or not finite(z) then return nil end
    if x % 1 ~= 0 or y % 1 ~= 0 or z % 1 ~= 0 then return nil end
    return { x = x, y = y, z = z }
end

function Orders.new(initial)
    local command = Orders.EXECUTABLE_REQUESTS[initial] and initial or Orders.DEFAULT
    return {
        requested = command, active = command, interrupted = nil,
        interruption = nil, guardPoint = nil, revision = 0
    }
end

-- Uma ordem do player nunca executa diretamente estados automaticos de emergencia.
function Orders.set(state, requested)
    if type(state) ~= "table" or not Orders.EXECUTABLE_REQUESTS[requested] then
        return false, "ordem desconhecida ou reservada para o sistema"
    end
    if state.requested ~= requested then
        state.requested = requested
        state.revision = (state.revision or 0) + 1
    end
    if not state.interruption then state.active = state.requested end
    return true
end

function Orders.setGuardPoint(state, x, y, z)
    if type(state) ~= "table" then return false, "estado invalido" end
    local point = position(x, y, z)
    if not point then return false, "coordenadas invalidas" end
    state.guardPoint = point
    state.revision = (state.revision or 0) + 1
    return true
end

function Orders.clearGuardPoint(state)
    if type(state) ~= "table" then return false end
    state.guardPoint = nil
    state.revision = (state.revision or 0) + 1
    return true
end

local INTERRUPTIONS = {
    RETREAT = {state = "RETREAT", priority = 100},
    SELF_DEFEND = {state = "SELF_DEFEND", priority = 90},
    PROTECT_PLAYER = {state = "PROTECT", priority = 70},
    PROTECT_GUARD = {state = "PROTECT", priority = 60}
}

-- Sintomas/sinais sao fornecidos pelo futuro adaptador de percepcao do PZ.
-- A maquina NAO inventa inimigos, danos ou coordenadas.
function Orders.evaluate(state, signals)
    if type(state) ~= "table" then return false, "estado invalido" end
    if signals ~= nil and type(signals) ~= "table" then
        return false, "sinais invalidos"
    end
    signals = signals or {}
    local reason
    if signals.mustRetreat == true then
        reason = "RETREAT"
    elseif signals.selfThreat == true then
        reason = "SELF_DEFEND"
    elseif signals.playerThreat == true then
        reason = "PROTECT_PLAYER"
    elseif signals.guardThreat == true and state.requested == "GUARD" and
           state.guardPoint ~= nil then
        reason = "PROTECT_GUARD"
    end

    local previous = state.active
    if reason then
        if not state.interruption then
            state.interrupted = state.requested
        end
        state.interruption = reason
        state.active = INTERRUPTIONS[reason].state
    else
        state.interruption = nil
        state.interrupted = nil
        state.active = state.requested or Orders.DEFAULT
    end
    if previous ~= state.active then
        state.revision = (state.revision or 0) + 1
    end
    return true, state.active
end

-- API antiga utilizada pelos testes e pelo nucleo do projeto.
function Orders.threat(state, threatened)
    if type(state) ~= "table" then return false end
    return Orders.evaluate(state, { selfThreat = threatened == true })
end

-- Estado para ModData: somente primitivos e tabelas novas, sem Java userdata.
function Orders.snapshot(state)
    if type(state) ~= "table" then return nil end
    local copy = {
        schema = 1,
        requested = state.requested,
        active = state.active,
        revision = tonumber(state.revision) or 0
    }
    if state.guardPoint then
        copy.guardPoint = position(state.guardPoint.x,
            state.guardPoint.y, state.guardPoint.z)
    end
    return copy
end

function Orders.restore(saved)
    if type(saved) ~= "table" then return Orders.new() end
    local state = Orders.new(saved.requested)
    if type(saved.guardPoint) == "table" then
        state.guardPoint = position(saved.guardPoint.x,
            saved.guardPoint.y, saved.guardPoint.z)
    end
    local revision = tonumber(saved.revision)
    if finite(revision) and revision >= 0 and revision % 1 == 0 then
        state.revision = revision
    end
    -- Um save nao deve carregar uma interrupcao/combate pendente.
    -- A proxima leitura real de ameacas decide o estado adequado.
    return state
end

Core.Orders = Orders
return Orders
