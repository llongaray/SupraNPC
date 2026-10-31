-- Regressao real de fila TimedAction B42, com motor simulado.
package.path="42/media/lua/client/?.lua;42/media/lua/shared/?.lua;" .. package.path
local timestamp=0
getTimestampMs=function() return timestamp end
getGameSpeed=function() return 1 end
local tiles={}
local function square(x,y,z)
    local key=x..":"..y..":"..z
    if not tiles[key] then
        tiles[key]={
            getX=function() return x end,getY=function() return y end,
            getZ=function() return z end,
            TreatAsSolidFloor=function() return true end,
            isFree=function() return true end,
            getMovingObjects=function() return {
                size=function() return 0 end
            } end
        }
    end
    return tiles[key]
end
getCell=function() return {
    getGridSquare=function(_,x,y,z) return square(x,y,z) end
} end
ISWalkToTimedAction={
    new=function(_,actor,sq)
        local action={actor=actor,target=sq}
        function action:setOnComplete(cb) self.onComplete=cb end
        function action:forceStop() self.stopped=true end
        function action:update() end
        function action:start() end
        function action:stop() end
        function action:perform() end
        return action
    end
}
ISTimedActionQueue={queues={},add=function(action)
    local q=ISTimedActionQueue.queues[action.actor]
    if not q then
        q={queue={}}
        ISTimedActionQueue.queues[action.actor]=q
    end
    q.queue[#q.queue+1]=action
end}
local Core=require("SupraNPC/Constants")
local Adapter=require("SupraNPC/SpawnAdapter")
local Walking=require("SupraNPC/NPCWalking")
local Controller=require("SupraNPC/NPCController")
Core.isSolo=function() return true end
local md={SupraNPC_IsNPC=true,SupraNPC_ID="npc1"}
local actor={
    getModData=function() return md end,
    getX=function() return 5 end,
    getY=function() return 5 end,
    getZ=function() return 0 end,
    isDead=function() return false end,
    getCurrentSquare=function() return square(5,5,0) end,
    getPathFindBehavior2=function() return {
        cancel=function() end
    } end
}
local player={getX=function() return 12 end,
    getY=function() return 13 end,getZ=function() return 0 end}
local profile={id="npc1",firstName="Lia",lastName="Teste"}
Adapter.actors.npc1=actor
Controller.clear()
assert(Controller.attach(profile,actor))
for i=1,15 do Controller.update(player) end
assert(Controller.get("npc1").navStatus=="MOVING")
assert(Walking.active("npc1"))
local q=ISTimedActionQueue.queues[actor]
assert(q and #q.queue==1)
local action=q.queue[1]
assert(action.target:getZ()==0 and action.target:getX()>=5)
-- Aguardar retira apenas a acao do NPC, evita re-enfileirar.
assert(Controller.order("npc1","IDLE",player))
assert(not Walking.active("npc1") and #q.queue==0 and action.stopped)
for i=1,90 do Controller.update(player) end
assert(#q.queue==0 and Controller.get("npc1").navStatus=="WAITING")
-- Guardar o ponto do jogador movimenta-se; guardar seu tile fica parado.
assert(Controller.order("npc1","GUARD",player,"PLAYER"))
for i=1,15 do Controller.update(player) end
assert(Walking.active("npc1"))
assert(Controller.order("npc1","GUARD",player,"NPC"))
for i=1,15 do Controller.update(player) end
assert(not Walking.active("npc1"))
assert(Controller.get("npc1").navStatus=="HOLD")
-- Falta de progresso na acao eh detectada, sem teleporte.
assert(Controller.order("npc1","FOLLOW",player))
for i=1,15 do Controller.update(player) end
assert(Walking.active("npc1"))
timestamp=7000
Controller.update(player)
assert(not Walking.active("npc1"))
assert(Controller.get("npc1").navStatus=="FAILED")
assert(Controller.get("npc1").navError=="sem progresso")
assert(actor.getX()==5 and actor.getY()==5)
print("[SupraNPC] movement_behavior_spec: OK")
