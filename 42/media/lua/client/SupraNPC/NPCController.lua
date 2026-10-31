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
        navError = nil, navDisabled = false, navTries = 0,
        nextRequestTick = 0, pathActive = false, stillTicks = 0,
        lastX = nil, lastY = nil, lastZ = nil, lastTarget = nil
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
    entry.pathActive = false
    entry.nextRequestTick = 0
    entry.lastX, entry.lastY, entry.lastZ = nil,nil,nil
    entry.stillTicks = 0
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

local function stopPath(entry)
    entry.pathActive = false
    entry.nextRequestTick = 0
    local path = entry.actor and call(entry.actor, "getPathFindBehavior2")
    if path and path.cancel then pcall(function() path:cancel() end) end
end

local function disabled(entry, reason)
    entry.navError = tostring(reason)
    entry.navTries = (entry.navTries or 0) + 1
    Core.log("NAV NPC " .. tostring(entry.profile.id) .. ": " .. entry.navError)
    if entry.navTries >= 3 then
        entry.navDisabled = true
        stopPath(entry)
        Core.log("NAV NPC " .. entry.profile.id ..
            ": falha repetida; ordens de movimento suspensas")
    end
end

-- O antigo código só enviava pathToCharacter() a cada 45 ticks.
-- Em IsoPlayer extra o comportamento NÃO é atualizado automaticamente
-- como ocorre em IsoGameCharacter com AI-state. Processar o resultado
-- do PathFindBehavior2 enquanto a ordem estiver ativa.
function Controller.update(player)
    if not player or not Core.isSolo() then return end
    Controller.ticks = Controller.ticks + 1
    for _, entry in pairs(Controller.entries) do
        local actor = entry.actor
        local command = entry.state and entry.state.active
        if actor and Adapter.get(entry.profile.id) == actor and
           call(actor, "isDead") ~= true and not entry.navDisabled then
            if command ~= "FOLLOW" and command ~= "GUARD" then
                if entry.pathActive then stopPath(entry) end
            else
                local tx, ty, tz
                if command == "FOLLOW" then
                    tx, ty, tz = call(player,"getX"), call(player,"getY"),
                        call(player,"getZ")
                elseif entry.state.guardPoint then
                    local p = entry.state.guardPoint
                    tx, ty, tz = p.x + 0.5, p.y + 0.5, p.z
                end
                local ax, ay, az = call(actor,"getX"), call(actor,"getY"),
                    call(actor,"getZ")
                if finite(tx) and finite(ty) and finite(tz) and
                   finite(ax) and finite(ay) and finite(az) then
                    local dx,dy = ax-tx, ay-ty
                    local threshold = command == "FOLLOW" and
                        Core.DEFAULT_FOLLOW_DISTANCE or 0.8
                    if az == tz and dx*dx+dy*dy <= threshold*threshold then
                        if entry.pathActive then stopPath(entry) end
                        entry.stillTicks = 0
                    else
                        local path = call(actor,"getPathFindBehavior2")
                        if not path or not path.update then
                            if Controller.ticks % 60 == 0 then
                                disabled(entry,"getPathFindBehavior2():update() indisponivel")
                            end
                        else
                            if Controller.ticks >= entry.nextRequestTick then
                                local ok, err = pcall(function()
                                    if command == "FOLLOW" then
                                        actor:pathToCharacter(player)
                                    else
                                        actor:pathToLocation(math.floor(tx),
                                            math.floor(ty), math.floor(tz))
                                    end
                                end)
                                if ok then
                                    entry.pathActive = true
                                    entry.nextRequestTick = Controller.ticks + 120
                                    entry.lastTarget = {x=tx,y=ty,z=tz}
                                    Core.log("NAV requisitada " .. entry.profile.id ..
                                        " destino=" .. math.floor(tx) ..
                                        "," .. math.floor(ty))
                                else
                                    disabled(entry,err)
                                    entry.nextRequestTick = Controller.ticks + 90
                                end
                            end
                            if entry.pathActive then
                                local ok, result = pcall(function()
                                    return path:update()
                                end)
                                if not ok then
                                    disabled(entry, result)
                                elseif result then
                                    local value = tostring(result):lower()
                                    if value:find("failed",1,true) or
                                        value:find("cancelled",1,true) then
                                        entry.pathActive = false
                                        entry.nextRequestTick = Controller.ticks + 75
                                        disabled(entry, "pathfinding retornou " .. value)
                                    elseif value:find("succeeded",1,true) then
                                        entry.pathActive = false
                                        entry.nextRequestTick = Controller.ticks + 30
                                    end
                                end
                            end
                            -- Fallback seguro: se a engine nao movimentar,
                            -- apenas registrar a falha; NUNCA teleportar.
                            if Controller.ticks % 45 == 0 then
                                local progress = entry.lastX == nil or
                                    math.abs(ax - entry.lastX) +
                                    math.abs(ay - entry.lastY) > 0.12 or
                                    az ~= entry.lastZ
                                if progress then
                                    entry.stillTicks = 0
                                    entry.navTries = 0
                                else
                                    entry.stillTicks = (entry.stillTicks or 0)+45
                                    if entry.stillTicks >= 270 then
                                        disabled(entry,"sem progresso apos 270 ticks")
                                        entry.stillTicks = 0
                                        entry.pathActive = false
                                        entry.nextRequestTick = Controller.ticks + 60
                                    end
                                end
                                entry.lastX, entry.lastY, entry.lastZ = ax,ay,az
                            end
                        end
                    end
                end
            end
        end
    end
    Adapter.restoreOwner(player)
end

return Controller
