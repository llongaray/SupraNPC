-- SupraNPC: detector deterministico de personagem preso, sem motor PZ.
-- Somente descreve REPATH/BLOCKED; um adaptador futuro executa a rota.
local Config = require("SupraNPC/Config")
local Monitor = {}
local function finite(v)
    return type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge
end

function Monitor.new(raw)
    local cfg = Config.sanitize(raw)
    return {
        threshold = cfg.stuckAfterTicks,
        attemptsMax = 3,
        attempts = 0, lastX = nil, lastY = nil, lastZ = nil,
        lastProgressTick = nil, lastTick = nil, blocked = false
    }
end

function Monitor.reset(state)
    if type(state) ~= "table" then return false end
    state.attempts = 0
    state.lastX, state.lastY, state.lastZ = nil, nil, nil
    state.lastProgressTick, state.lastTick = nil, nil
    state.blocked = false
    return true
end

-- Retorno: IDLE, TRACKING, MOVING, WAIT, REPATH, BLOCKED ou nil + erro.
-- tick deve ser contador monotônico fornecido pelo integrador.
function Monitor.observe(state, x, y, z, tick, hasGoal)
    if type(state) ~= "table" then return nil, "estado invalido" end
    if not finite(x) or not finite(y) or not finite(z) or
       not finite(tick) or tick < 0 or tick % 1 ~= 0 then
        return nil, "posicao/tick invalidos"
    end
    if hasGoal ~= true then
        Monitor.reset(state)
        return "IDLE"
    end
    if state.lastTick and tick < state.lastTick then
        Monitor.reset(state)
    elseif state.lastTick == tick then
        return state.blocked and "BLOCKED" or "WAIT"
    end
    state.lastTick = tick
    if state.lastX == nil then
        state.lastX, state.lastY, state.lastZ = x, y, z
        state.lastProgressTick = tick
        return "TRACKING"
    end

    local dx, dy = x - state.lastX, y - state.lastY
    local moved = (dx * dx + dy * dy) >= 0.15 * 0.15 or z ~= state.lastZ
    if moved then
        state.lastX, state.lastY, state.lastZ = x, y, z
        state.lastProgressTick = tick
        state.attempts = 0
        state.blocked = false
        return "MOVING"
    end
    if state.blocked then return "BLOCKED" end
    if tick - state.lastProgressTick < state.threshold then return "WAIT" end

    state.attempts = state.attempts + 1
    state.lastProgressTick = tick
    if state.attempts >= state.attemptsMax then
        state.blocked = true
        return "BLOCKED"
    end
    return "REPATH"
end

return Monitor
