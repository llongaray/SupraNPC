-- Ciclo de seguimento com passos espaçados. Somente NPCs instanciados.
-- O pathfinding ainda depende de validação das APIs da build local.
local Core = require("SupraNPC/Constants")
local Orders = require("SupraNPC/Orders")
local Follow = { actors = {}, ticks = 0 }

function Follow.register(id, actor)
    if not id or not actor then return false end
    Follow.actors[id] = { actor = actor, state = Orders.new("FOLLOW") }
    return true
end

function Follow.clear()
    Follow.actors = {}
    Follow.ticks = 0
end

function Follow.update(player)
    if not player or not Core.EXPERIMENTAL_SPAWN then return end
    Follow.ticks = Follow.ticks + 1
    if Follow.ticks % Core.THINK_INTERVAL ~= 0 then return end
    for id, entry in pairs(Follow.actors) do
        if entry.state.active == "FOLLOW" then
            local npc = entry.actor
            local ok, err = pcall(function()
                if not npc or (npc.isDead and npc:isDead()) then
                    Follow.actors[id] = nil
                    return
                end
                local dx, dy = npc:getX() - player:getX(), npc:getY() - player:getY()
                local distance2 = dx * dx + dy * dy
                if npc:getZ() ~= player:getZ() or distance2 >
                        Core.DEFAULT_FOLLOW_DISTANCE * Core.DEFAULT_FOLLOW_DISTANCE then
                    if npc.pathToCharacter then
                        npc:pathToCharacter(player)
                    elseif npc.pathToLocation then
                        npc:pathToLocation(math.floor(player:getX()), math.floor(player:getY()), math.floor(player:getZ()))
                    end
                end
            end)
            if not ok then
                Core.log("Follow " .. tostring(id) .. " falhou: " .. tostring(err))
                Follow.actors[id] = nil
            end
        end
    end
end

Core.Follow = Follow
return Follow
