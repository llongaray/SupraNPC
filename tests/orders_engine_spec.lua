-- Testes do controlador de ordens, 100% independentes do Project Zomboid.
package.path = "42/media/lua/shared/?.lua;" .. package.path
local Orders = require("SupraNPC/Orders")

local function eq(a,b) assert(a == b, tostring(a) .. " != " .. tostring(b)) end
local state = Orders.new("FOLLOW")
eq(state.active, "FOLLOW")
assert(not Orders.set(state, "SELF_DEFEND")) -- estados automaticos nao sao ordens
assert(not Orders.set(state, "INVALID"))
assert(not Orders.setGuardPoint(state, 1/0, 5, 0))
assert(not Orders.setGuardPoint(state, 1.5, 5, 0))
assert(Orders.setGuardPoint(state, 100, 200, 0))
eq(state.guardPoint.x, 100)

assert(Orders.set(state, "GUARD"))
eq(state.active, "GUARD")
Orders.evaluate(state, {guardThreat=true})
eq(state.active, "PROTECT")
eq(state.interruption, "PROTECT_GUARD")
Orders.evaluate(state, {guardThreat=true, playerThreat=true})
eq(state.interruption, "PROTECT_PLAYER")
Orders.evaluate(state, {guardThreat=true, playerThreat=true, selfThreat=true})
eq(state.active, "SELF_DEFEND")
Orders.evaluate(state, {mustRetreat=true, selfThreat=true})
eq(state.active, "RETREAT")

-- Nova ordem durante uma interrupcao: so executa quando termina a ameaca.
assert(Orders.set(state, "FOLLOW"))
eq(state.active, "RETREAT")
Orders.evaluate(state, {})
eq(state.active, "FOLLOW")
assert(state.interruption == nil and state.interrupted == nil)

-- Guardar lugar requer ponto valido e ordem GUARDA.
assert(Orders.set(state, "GUARD"))
Orders.clearGuardPoint(state)
Orders.evaluate(state, {guardThreat=true})
eq(state.active, "GUARD")
assert(Orders.setGuardPoint(state, -300, 1000, 1))
Orders.evaluate(state, {guardThreat=true})
eq(state.active, "PROTECT")
Orders.evaluate(state, {})
eq(state.active, "GUARD")

local saved = Orders.snapshot(state)
assert(saved.guardPoint and saved.guardPoint.x == -300)
saved.guardPoint.x = 90
eq(state.guardPoint.x, -300) -- copia independente
local restored = Orders.restore(Orders.snapshot(state))
eq(restored.requested, "GUARD")
eq(restored.active, "GUARD")
eq(restored.guardPoint.z, 1)
Orders.evaluate(state, {selfThreat=true})
local recovered = Orders.restore(Orders.snapshot(state))
eq(recovered.active, "GUARD") -- nao carregar ataque/fuga de save anterior

-- Precedencia e determinismo exaustivos: 16 combinacoes de sinais.
for mask = 0, 15 do
    local signals = {
        mustRetreat = (mask % 2) == 1,
        selfThreat = (math.floor(mask / 2) % 2) == 1,
        playerThreat = (math.floor(mask / 4) % 2) == 1,
        guardThreat = (math.floor(mask / 8) % 2) == 1
    }
    local a = Orders.new("GUARD")
    Orders.setGuardPoint(a, 0, 0, 0)
    local ok, result = Orders.evaluate(a, signals)
    assert(ok and result == a.active)
    if signals.mustRetreat then
        eq(result, "RETREAT")
    elseif signals.selfThreat then
        eq(result, "SELF_DEFEND")
    elseif signals.playerThreat or signals.guardThreat then
        eq(result, "PROTECT")
    else
        eq(result, "GUARD")
    end
end

assert(not Orders.evaluate(state, "bad"))
local invalid = Orders.restore({requested = "SELF_DEFEND",guardPoint={x="bad",y=1,z=0}})
eq(invalid.active, "FOLLOW")
assert(invalid.guardPoint == nil)
print("[SupraNPC] orders_engine_spec: OK")
