-- SupraNPC - controlador de ordens da equipe (somente B42 single-player).
-- Seguir/retornar ao ponto sao experimentais: sem teleporte, ataque ou zumbis.
local Core = require("SupraNPC/Constants")
local Orders = require("SupraNPC/Orders")
local Adapter = require("SupraNPC/SpawnAdapter")
local Controller = { entries = {}, ticks = 0, interval = 45 }
local STANCES = { PASSIVE = true, DEFENSIVE = true, AGGRESSIVE = true }

local function call(obj, method, ...)
    if not obj then return nil end
    local args = {...}
    local ok, res = pcall(function() return obj[method](obj, unpack(args)) end)
    if ok then return res end
    return nil
end
local function finite(n)
    return type(n) == "number" and n == n and n ~= math.huge and n ~= -math.huge
end

function Controller.clear()
    Controller.entries, Controller.ticks = {}, 0
end

function Controller.attach(profile, actor)
    if not profile or not actor or type(profile.id) ~= "string" or
       Adapter.get(profile.id) ~= actor then return false end
    if Controller.entries[profile.id] and
       Controller.entries[profile.id].actor == actor then return true end
    local md = call(actor, "getModData")
    if not md or md.SupraNPC_ID ~= profile.id or
       md.SupraNPC_IsNPC ~= true then return false end
    local saved = profile.commandState or md.SupraNPC_CommandState
    local state = Orders.restore(saved or {requested=profile.order or "FOLLOW"})
    local stance = STANCES[profile.stance] and profile.stance or "DEFENSIVE"
    Controller.entries[profile.id] = {
        actor = actor, profile = profile, state = state, stance = stance,
        navError = nil, navDisabled = false, navTries = 0
    }
    md.SupraNPC_Stance = stance
    md.SupraNPC_Order = state.requested
    return true
end

function Controller.get(id)
    return Controller.entries[id]
end

local function persist(entry)
    entry.profile.commandState = Orders.snapshot(entry.state)
    entry.profile.order = entry.state.requested
    entry.profile.stance = entry.stance
    local md = call(entry.actor, "getModData")
    if md then
        md.SupraNPC_CommandState = Orders.snapshot(entry.state)
        md.SupraNPC_Order = entry.state.requested
        md.SupraNPC_Stance = entry.stance
    end
end

function Controller.order(id, command, player, which)
    local entry = Controller.entries[id]
    if not entry then return false, "NPC nao registrado" end
    if command ~= "FOLLOW" and command ~= "IDLE" and command ~= "GUARD" then
        return false, "Comando nao disponivel nesta versao"
    end
    if command == "GUARD" then
        local target = which == "PLAYER" and player or entry.actor
        if not target then return false, "Alvo da guarda ausente" end
        local x, y, z = call(target, "getX"), call(target, "getY"), call(target, "getZ")
        if not finite(x) or not finite(y) or not finite(z) then
            return false, "Posicao invalida"
        end
        local ok, err = Orders.setGuardPoint(entry.state,
            math.floor(x), math.floor(y), math.floor(z))
        if not ok then return false, err end
    end
    local ok, reason = Orders.set(entry.state, command)
    if not ok then return false, reason end
    entry.navDisabled = false
    entry.navError = nil
    entry.navTries = 0
    persist(entry)
    Core.log("ORDEM NPC " .. id .. " => " .. command)
    return true
end

function Controller.stance(id, stance)
    local entry = Controller.entries[id]
    if not entry then return false, "NPC nao registrado" end
    if not STANCES[stance] then return false, "Postura invalida" end
    entry.stance = stance
    persist(entry)
    Core.log("POSTURA NPC " .. id .. " => " .. stance ..
        " (combate autonomo ainda nao implementado)")
    return true
end

local function move(entry, player, target, isFollow)
    if entry.navDisabled then return end
    local npc = entry.actor
    if not npc or call(npc, "isDead") == true then return end
    local ax, ay, az = call(npc,"getX"), call(npc,"getY"), call(npc,"getZ")
    local tx, ty, tz
    if isFollow then
        tx, ty, tz = call(player,"getX"), call(player,"getY"), call(player,"getZ")
    else
        tx, ty, tz = target.x, target.y, target.z
    end
    if not finite(ax) or not finite(ay) or not finite(az) or
       not finite(tx) or not finite(ty) or not finite(tz) then return end
    local dist2 = (ax-tx)^2 + (ay-ty)^2
    local minimum = isFollow and Core.DEFAULT_FOLLOW_DISTANCE or 1
    if az == tz and dist2 <= minimum * minimum then return end
    -- Nunca modificar controle/camera. Apenas pedir caminho ao ator adicional.
    local ok, err = pcall(function()
        if isFollow and npc.pathToCharacter then
            npc:pathToCharacter(player)
        elseif npc.pathToLocation then
            npc:pathToLocation(math.floor(tx), math.floor(ty), math.floor(tz))
        else
            error("API de pathfinding indisponivel para IsoPlayer NPC")
        end
    end)
    if not ok then
        entry.navTries = entry.navTries + 1
        entry.navError = tostring(err)
        if entry.navTries >= 2 then
            entry.navDisabled = true
            Core.log("NAVEGACAO NPC " .. entry.profile.id .. " desativada: " ..
                entry.navError)
        end
    else
        entry.navTries = 0
    end
end

function Controller.update(player)
    if not player or not Core.isSolo() then return end
    Controller.ticks = Controller.ticks + 1
    if Controller.ticks % Controller.interval ~= 0 then return end
    for _, entry in pairs(Controller.entries) do
        if entry.actor and Adapter.get(entry.profile.id) == entry.actor then
            if entry.state.active == "FOLLOW" then
                move(entry, player, nil, true)
            elseif entry.state.active == "GUARD" and entry.state.guardPoint then
                move(entry, player, entry.state.guardPoint, false)
            end
        end
    end
    Adapter.restoreOwner(player)
end

return Controller
