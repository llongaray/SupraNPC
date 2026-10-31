-- SupraNPC v0.1.12: movimento por TimedAction nativa da B42.
-- Adaptado do ArayHumanWalking.lua do proprio autor, mantendo fila por IsoPlayer.
-- Nunca criar zumbis, reposicionar NPC, controlar camera ou entrar na fila do jogador.
local Core = require("SupraNPC/Constants")
local Adapter = require("SupraNPC/SpawnAdapter")
local Navigation = require("SupraNPC/NPCNavigation")
pcall(require, "TimedActions/WalkToTimedAction")
pcall(require, "TimedActions/ISTimedActionQueue")
local W = { walks = {}, serial = 0, timeoutMs = 30000, noProgressMs = 6000 }
local function call(o, k, ...)
    if not o then return nil end
    local args = {...}
    local ok, value = pcall(function()
        if o[k] then return o[k](o, unpack(args)) end
    end)
    if ok then return value end
    return nil
end
local function now()
    if getTimestampMs then
        local ok, ms = pcall(getTimestampMs)
        if ok and type(ms) == "number" then return ms end
    end
    return 0
end
local function dist(c, x, y)
    return math.sqrt((c:getX() - x)^2 + (c:getY() - y)^2)
end
local function owned(r)
    return W.walks[r.id] == r and not r.done
end
local function queued(r)
    local queue = ISTimedActionQueue and ISTimedActionQueue.queues
        and ISTimedActionQueue.queues[r.actor]
    if not queue or not queue.queue then return false end
    for _, action in ipairs(queue.queue) do
        if action == r.action then return true end
    end
    return false
end
function W.free(square, ignore)
    if not square or call(square, "TreatAsSolidFloor") ~= true or
       call(square, "isFree", false) ~= true then return false end
    local objects = call(square, "getMovingObjects")
    local count = objects and call(objects, "size") or 0
    if type(count) ~= "number" then return false end
    for i=0,math.min(count,128)-1 do
        local obj = call(objects, "get", i)
        if obj and obj ~= ignore and instanceof and
           instanceof(obj, "IsoGameCharacter") then return false end
    end
    return true
end
function W.pickAround(x,y,z,actor)
    local cell=getCell and getCell()
    if not cell then return nil end
    local offsets={{1,0},{-1,0},{0,1},{0,-1},
        {1,1},{-1,1},{1,-1},{-1,-1},{2,0},{-2,0},{0,2},{0,-2}}
    local best,score=nil,math.huge
    for _,offset in ipairs(offsets) do
        local square=call(cell,"getGridSquare",x+offset[1],y+offset[2],z)
        if W.free(square,actor) then
            local d=dist(actor,x+offset[1]+0.5,y+offset[2]+0.5)
            if d<score then best,score=square,d end
        end
    end
    return best
end
-- Escolhe a casa LIVRE mais distante da ameaca, no sentido de fuga.
-- Nunca gera tiles nao carregados e nunca teleporta.
function W.pickRetreat(actor,threat,steps)
    if not actor or not threat or not getCell then return nil end
    local cell=getCell()
    if not cell then return nil end
    local ax,ay,az=actor:getX(),actor:getY(),math.floor(actor:getZ())
    local zx,zy=threat:getX(),threat:getY()
    local dx,dy=ax-zx,ay-zy
    local length=math.sqrt(dx*dx+dy*dy)
    if length<0.01 then dx,dy,length=1,0,1 end
    dx,dy=dx/length,dy/length
    steps=math.max(1,math.min(5,math.floor(tonumber(steps) or 2)))
    local best,score=nil,-math.huge
    local bx,by=math.floor(ax),math.floor(ay)
    for ox=-steps,steps do
        for oy=-steps,steps do
            local projection=ox*dx+oy*dy
            if projection>0.6 and ox*ox+oy*oy<=steps*steps then
                local square=call(cell,"getGridSquare",bx+ox,by+oy,az)
                if W.free(square,actor) then
                    -- Safe retreat uses the same loaded, wall-aware planner.
                    -- Never open a portal while fleeing; choose a walkable
                    -- first step only if an alternative route exists.
                    local md=call(actor,"getModData")
                    local ownerId=md and md.SupraNPC_ID or ""
                    local waypoint=Navigation.next(actor,bx+ox+0.5,
                        by+oy+0.5,az,ownerId,W.free,0.70,true)
                    if waypoint then
                        local away=(bx+ox+0.5-zx)^2+(by+oy+0.5-zy)^2
                        local sideways=math.abs(ox*dy-oy*dx)
                        local value=away-sideways*0.6
                        if value>score then best,score=waypoint,value end
                    end
                end
            end
        end
    end
    return best
end
function W.pickNear(player, actor)
    if not player or not actor or not getCell then return nil end
    local cell = getCell()
    if not cell then return nil end
    local x, y, z = math.floor(player:getX()), math.floor(player:getY()),
        math.floor(player:getZ())
    local offsets = {
        {1,0},{-1,0},{0,1},{0,-1},{1,1},{1,-1},{-1,1},{-1,-1},
        {2,0},{-2,0},{0,2},{0,-2},{2,1},{2,-1},{-2,1},{-2,-1}
    }
    local best, score = nil, math.huge
    for _, offset in ipairs(offsets) do
        local square = call(cell, "getGridSquare",x+offset[1],y+offset[2],z)
        if W.free(square,actor) then
            local d = dist(actor, x+offset[1]+0.5, y+offset[2]+0.5)
            if d < score then best,score=square,d end
        end
    end
    return best
end
local function finish(r, result)
    if not owned(r) then return end
    r.done, r.result = true, result
    Core.log("WALK " .. r.id .. " result=" .. result ..
        " destination=" .. r.x .. "," .. r.y)
    if r.callback then pcall(r.callback,result) end
end
function W.cancel(id, reason)
    local r = W.walks[id]
    if not r or r.done then return false end
    -- Invalida antes da chamada ao native stop: nao executar callback tardio.
    r.done, r.result = true, reason or "cancelado"
    local action=r.action
    if action and action.forceStop then pcall(function() action:forceStop() end) end
    local q = ISTimedActionQueue and ISTimedActionQueue.queues
        and ISTimedActionQueue.queues[r.actor]
    if q and q.queue then
        for i=#q.queue,1,-1 do
            if q.queue[i] == action then table.remove(q.queue,i) end
        end
        if q.current == action then q.current = nil end
    end
    pcall(function()
        local path=r.actor:getPathFindBehavior2()
        if path then path:cancel() end
        if r.actor.setPath2 then r.actor:setPath2(nil) end
    end)
    Core.log("WALK " .. id .. " cancelado=" .. r.result)
    if r.callback then pcall(r.callback,r.result) end
    return true
end
function W.active(id)
    local r=W.walks[id]
    return r ~= nil and not r.done
end
function W.state(id)
    local r=W.walks[id]
    return r and {active=not r.done, result=r.result,
        queued=not r.done and queued(r), x=r.x,y=r.y,z=r.z,
        remaining=dist(r.actor,r.x+0.5,r.y+0.5)} or nil
end
function W.start(id, actor, square, callback)
    if type(id) ~= "string" or not actor or
       Adapter.get(id) ~= actor or not square then
        return false, "ator/destino invalido"
    end
    local md=call(actor,"getModData")
    if not md or md.SupraNPC_IsNPC ~= true or md.SupraNPC_ID ~= id then
        return false, "NPC nao identificado"
    end
    if not ISWalkToTimedAction or not ISTimedActionQueue or
       not ISTimedActionQueue.add or not ISTimedActionQueue.queues then
        return false, "ISWalkToTimedAction indisponivel"
    end
    if getGameSpeed and getGameSpeed() > 2 then return false, "velocidade do jogo" end
    local current=call(actor,"getCurrentSquare") or call(actor,"getSquare")
    if not current or
       math.floor(actor:getZ()) ~= call(square,"getZ") or
       not W.free(square,actor) then return false,"tile bloqueado ou chunk ausente" end
    local q = ISTimedActionQueue.queues[actor]
    if q and q.queue and #q.queue>0 and not W.active(id) then
        return false, "fila de outra acao ocupada"
    end
    W.cancel(id, "substituido")
    q=ISTimedActionQueue.queues[actor]
    if q and q.queue and #q.queue>0 then return false,"fila nao liberada" end
    local ok, action=pcall(function() return ISWalkToTimedAction:new(actor,square) end)
    if not ok or not action then return false,"criacao TimedAction falhou: "..tostring(action) end
    W.serial=W.serial+1
    local r={id=id,actor=actor,action=action,serial=W.serial,
        x=square:getX(),y=square:getY(),z=square:getZ(),
        started=now(),lastProgress=now(),lastX=actor:getX(),
        lastY=actor:getY(),callback=callback,done=false}
    W.walks[id]=r
    for _, method in ipairs({"start","update","stop","perform"}) do
        local original=action[method]
        if original then
            action[method]=function(self,...)
                if owned(r) then return original(self,...) end
            end
        end
    end
    if action.setOnComplete then
        action:setOnComplete(function()
            if not owned(r) then return end
            local close=math.floor(actor:getX()) == r.x and
                math.floor(actor:getY()) == r.y and
                dist(actor,r.x+0.5,r.y+0.5) <= 0.9
            finish(r,close and "sucesso" or "destino nao alcancado")
        end)
    end
    local added, why=pcall(function() ISTimedActionQueue.add(action) end)
    if not added or not queued(r) then
        W.cancel(id,"fila rejeitada")
        return false,"acao nao enfileirada: "..tostring(why)
    end
    Core.log("WALK " .. id .. " start id=" .. r.serial .. " target=" ..
        r.x .. "," .. r.y .. "," .. r.z)
    return true
end
function W.update()
    local stamp=now()
    for id,r in pairs(W.walks) do
        if not r.done then
            if Adapter.get(id) ~= r.actor or call(r.actor,"isDead") == true then
                W.cancel(id,"entidade ausente")
            elseif stamp-r.started > W.timeoutMs then
                W.cancel(id,"timeout")
            elseif BehaviorResult and r.action.result == BehaviorResult.Failed then
                W.cancel(id,"pathfinding_failed")
            elseif not queued(r) then
                if math.floor(r.actor:getX())==r.x and
                   math.floor(r.actor:getY())==r.y then
                    finish(r,"sucesso")
                else W.cancel(id,"saida inesperada da fila") end
            elseif dist(r.actor,r.lastX,r.lastY)>=0.10 then
                r.lastProgress=stamp
                r.lastX,r.lastY=r.actor:getX(),r.actor:getY()
            elseif stamp-r.lastProgress>W.noProgressMs then
                W.cancel(id,"sem progresso")
            end
        end
    end
end
return W
