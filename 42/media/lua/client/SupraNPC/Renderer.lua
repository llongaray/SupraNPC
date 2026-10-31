-- SupraNPC - renderizacao de IsoPlayer extra na Build 42.
-- Adaptado do ArayHumanNPCTest (mesmo autor, implementacao ja experimentada).
-- O renderer padrão pode ignorar IsoPlayer fora de IsoPlayer.players[].
local Core = require("SupraNPC/Constants")
local Adapter = require("SupraNPC/SpawnAdapter")
local Render = { calls = 0, failed = false, disabledReason = nil }
local cutawayFailed = false
local fboCached = nil

local function call(obj, method, ...)
    if not obj then return nil end
    local args = {...}
    local ok, value = pcall(function() return obj[method](obj, unpack(args)) end)
    if ok then return value end
end

local function fboEnabled()
    if fboCached ~= nil then return fboCached end
    local ok, value = pcall(function() return PerformanceSettings.fboRenderChunk end)
    -- A versão original usa true caso a opção não seja exposta.
    fboCached = (not ok or value == nil) and true or value == true
    return fboCached
end

local function visibleThroughCutaway(index, square)
    if cutawayFailed or not FBORenderCutaways or
        not FBORenderCutaways.getInstance then return true end
    local ok, visible = pcall(function()
        return FBORenderCutaways.getInstance():
            shouldRenderBuildingSquare(index, square)
    end)
    if not ok then
        cutawayFailed = true
        Core.log("Render: cutaway indisponivel; fallback sem filtro")
        return true
    end
    return visible == true
end

local function one(index, actor)
    if not actor or call(actor, "isDead") == true then return end
    local cell = getCell and getCell()
    local objects = call(cell, "getObjectList")
    if not objects or call(objects, "contains", actor) ~= true then return end
    local square = call(actor, "getCurrentSquare")
    if not square or call(actor, "isOnScreen") ~= true then return end
    local light = call(square, "getLightInfo", index)
    if not light or not visibleThroughCutaway(index, square) then return end
    local ok, err = pcall(function()
        actor:render(actor:getX(), actor:getY(), actor:getZ(),
            light, true, false, nil)
    end)
    if not ok then
        Render.failed = true
        Render.disabledReason = tostring(err)
        Core.log("Render de IsoPlayer extra DESATIVADO apos falha: " ..
            tostring(err))
        return
    end
    Render.calls = Render.calls + 1
    if Render.calls == 1 then
        Core.log("Render humano ativo via RenderOpaqueObjectsInWorld")
    end
end

function Render.update(index)
    if Render.failed or not Core.EXPERIMENTAL_SPAWN or not Core.isSolo() then
        return
    end
    if not fboEnabled() then return end
    index = tonumber(index) or 0
    for _, actor in pairs(Adapter.actors) do
        one(index, actor)
        if Render.failed then break end
    end
end

function Render.maintain(player)
    if not player or not Core.isSolo() then return end
    for _, actor in pairs(Adapter.actors) do
        if actor and call(actor, "isDead") ~= true then
            -- Algumas instancias perdem alfa mesmo estando perto.
            local dx = call(actor, "getX")
            local dy = call(actor, "getY")
            if dx and dy and (dx - player:getX())^2 +
                (dy - player:getY())^2 < 80 * 80 then
                if (call(actor, "getAlpha") or 1) < 0.05 and
                    (call(actor, "getTargetAlpha") or 1) < 0.05 then
                    call(actor, "setAlpha", 1)
                    call(actor, "setTargetAlpha", 1)
                    call(actor, "setSceneCulled", false)
                end
            end
        end
    end
    -- O construtor IsoPlayer pode alterar referencias internas do player.
    Adapter.restoreOwner(player)
end

function Render.reset()
    Render.calls = 0
    Render.failed = false
    Render.disabledReason = nil
    fboCached = nil
    cutawayFailed = false
end

if Events and Events.RenderOpaqueObjectsInWorld then
    Events.RenderOpaqueObjectsInWorld.Add(Render.update)
else
    Core.log("RenderOpaqueObjectsInWorld ausente: NPC pode ficar invisivel")
end

Core.Renderer = Render
return Render
