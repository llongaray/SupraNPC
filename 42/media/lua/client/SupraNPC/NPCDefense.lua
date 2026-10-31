-- SupraNPC: defesa deterministica de curta distancia contra IsoZombie.
-- Inspirado na selecao de alvo de Super Survivors/AttackTask e KnoxSurvivors.
-- Dano: IsoZombie:Hit(HandWeapon, IsoGameCharacter, float, boolean, float)
-- Sempre validar o alvo no instante do golpe; NUNCA atingir IsoPlayer/NPC.
local Core = require("SupraNPC/Constants")
local Orders = require("SupraNPC/Orders")
local Walking = require("SupraNPC/NPCWalking")
local Tactics = require("SupraNPC/CombatTactics")
local Perception = require("SupraNPC/NPCPerception")
local Speech = require("SupraNPC/NPCSpeech")
local D = { RADIUS=4.0, REACH=1.45, PERIOD_MS=1050, MAX_SQUARES=81,
    MAX_OBJECTS=280, MAX_CHASE=4.0, STATES={} }
local function call(o,k,...)
    if not o then return nil end
    local args={...}
    local ok,value=pcall(function()
        if o[k] then return o[k](o,unpack(args)) end
    end)
    if ok then return value end
end
local function finite(n)
    return type(n)=="number" and n==n and n~=math.huge and n~=-math.huge
end
local function zombie(o)
    if not o or not instanceof then return false end
    local ok,result=pcall(instanceof,o,"IsoZombie")
    return ok and result==true and call(o,"isDead")==false
end
local function now()
    if getTimestampMs then
        local ok,stamp=pcall(getTimestampMs)
        if ok and finite(stamp) then return stamp end
    end
    return 0
end
local function distance(a,b)
    local ax,ay,az=call(a,"getX"),call(a,"getY"),call(a,"getZ")
    local bx,by,bz=call(b,"getX"),call(b,"getY"),call(b,"getZ")
    if not finite(ax) or not finite(ay) or not finite(az) or
       not finite(bx) or not finite(by) or not finite(bz) or
       math.floor(az)~=math.floor(bz) then return nil end
    return math.sqrt((ax-bx)^2+(ay-by)^2)
end
local function canSee(actor, target, d)
    local result=call(actor,"CanSee",target)
    if result==true then return true end
    -- CanSee falhou/retornou false: nao tentar golpe atravessando obstaculos.
    -- Requer visibilidade expressa para alcance maior que mesmo tile.
    if d and d<0.65 and call(actor,"getCurrentSquare")==
        call(target,"getCurrentSquare") then return true end
    return false
end
function D.scan(actor)
    local obs=Perception.observe(actor)
    return obs.nearest or obs.nearestDown
end
local function weaponOf(actor)
    local w=call(actor,"getPrimaryHandItem")
    if w and instanceof then
        local ok,isWeapon=pcall(instanceof,w,"HandWeapon")
        if ok and isWeapon and call(w,"isAimedFirearm")~=true and
           call(w,"isBroken")~=true then return w end
    end
    -- Busca arma de ataque desarmado nativa se a engine a disponibilizar.
    local bare=call(actor,"getAttackingWeapon")
    if bare and instanceof then
        local ok,isWeapon=pcall(instanceof,bare,"HandWeapon")
        if ok and isWeapon and call(bare,"isAimedFirearm")~=true then
            return bare
        end
    end
    -- A arma virtual da engine (Base.BareHands) permite defesa desarmada.
    -- Apenas instanciar o item oficial; nao adicionar arma falsa ao inventario.
    if InventoryItemFactory and InventoryItemFactory.CreateItem then
        local ok,item=pcall(InventoryItemFactory.CreateItem,"Base.BareHands")
        if ok and item and instanceof then
            local yes,valid=pcall(instanceof,item,"HandWeapon")
            if yes and valid then return item end
        end
    end
    return nil
end
function D.hit(actor,target)
    if not zombie(target) or not actor or call(actor,"isDead")~=false then
        return false,"alvo invalido"
    end
    local d=distance(actor,target)
    if not d or d>D.REACH or not canSee(actor,target,d) then
        return false,"alvo fora do alcance ou sem visibilidade"
    end
    local weapon=weaponOf(actor)
    if not weapon then return false,"sem HandWeapon corpo a corpo" end
    local weaponRange=call(weapon,"getMaxRange")
    if finite(weaponRange) and d>math.min(D.REACH,weaponRange) then
        return false,"fora do alcance desta arma"
    end
    local min=call(weapon,"getMinDamage")
    local max=call(weapon,"getMaxDamage")
    if not finite(min) or not finite(max) or max<=0 then
        return false,"arma sem dano corpo a corpo valido"
    end
    -- Dano limitado: evita kills artificiais enormes de armas modded.
    local damage=math.max(0.05,math.min(0.65,(math.max(0,min)+max)/2))
    if not target.Hit then return false,"IsoZombie.Hit indisponivel" end
    -- Somente chamar Hit no zombie explicitamente selecionado; ataques
    -- nativos que selecionam colisao automaticamente podem atingir aliados.
    pcall(function() if actor.faceThisObject then actor:faceThisObject(target) end end)
    local ok,res=pcall(function()
        return target:Hit(weapon,actor,damage,false,1.0,false)
    end)
    if not ok then return false,"Hit falhou: "..tostring(res) end
    Core.log("DEFENSE HIT zombie damage="..string.format("%.2f",damage))
    return true
end
local function cancel(entry,why)
    if Walking.active(entry.profile.id) then
        Walking.cancel(entry.profile.id,why)
    end
end
local function fallen(target) return Perception.isDown(target) end
function D.observe(actor,player,team)
    return Perception.observe(actor,player,team)
end
local function validTarget(actor,target,limit)
    local d=distance(actor,target)
    return d and d<=limit and zombie(target) and canSee(actor,target,d),d
end
-- Empurrao fisico simplificado: queda via metodo nativo knockDown.
-- IMPORTANTE: nao comprova animacao de shove e nao inventa isOnFloor.
-- Queda so ocorre se verificacao de alcance/visao e sorte permitirem.
function D.shove(actor,target)
    local ok,d=validTarget(actor,target,Tactics.SHOVE_RANGE)
    if not ok or fallen(target) then return false,"alvo nao empurravel" end
    if not target.knockDown then return false,"knockDown indisponivel" end
    if call(actor,"canPerformHandToHandCombat")==false then
        return false,"maos ocupadas" end
    local strength=0
    if Perks and Perks.Strength then
        local value=call(actor,"getPerkLevel",Perks.Strength)
        if finite(value) then strength=math.max(0,math.min(10,value)) end
    end
    -- Chance de desequilibrio: o zumbi pode continuar de pe.
    local chance=math.min(85,50+strength*3)
    local okRoll,roll=pcall(function() return ZombRand and ZombRand(100) end)
    if not okRoll or not finite(roll) then return false,"RNG do jogo indisponivel" end
    pcall(function() if actor.faceThisObject then actor:faceThisObject(target) end end)
    if roll>=chance then
        Core.log("TACTIC shove resisted / zombie remains standing")
        return true,"resistiu"
    end
    local success,err=pcall(function() target:knockDown(false) end)
    if not success then return false,"knockDown: "..tostring(err) end
    Core.log("TACTIC shove knockDown invoked; awaiting isOnFloor")
    return true,"queda solicitada"
end
local function moveTo(entry,square,reason)
    local id=entry.profile.id
    if not square then
        entry.navError="tactical square blocked: "..reason
        return false
    end
    if Walking.active(id) then return true end
    local ok,why=Walking.start(id,entry.actor,square)
    if not ok then
        entry.navError="tactical move: "..tostring(why)
        return false
    end
    return true
end
local function moveAway(entry,threat,step,reason)
    if not threat then return false end
    local tile=Walking.pickRetreat and
        Walking.pickRetreat(entry.actor,threat,step)
    return moveTo(entry,tile,reason)
end
function D.reset(id)
    local record=D.STATES[id]
    if record and record.entry then cancel(record.entry,"combat reset") end
    D.STATES[id]=nil
end
function D.clear()
    for id in pairs(D.STATES) do D.reset(id) end
end
-- Called before ALL manual orders on every controller update.
-- player/team needed to distinguish solo escape from supported group defense.
function D.update(entry,player,team)
 local id=entry and entry.profile and entry.profile.id
 if not id then return false end
 local actor=entry.actor
 local old=D.STATES[id]
 if call(actor,"isDead")~=false then
    if old then D.reset(id) end
    return false
 end
 local obs=Perception.observe(actor,player,team)
 local health=call(call(actor,"getBodyDamage"),"getOverallBodyHealth")
 local danger=Perception.risk(obs,health)
 local visible=obs.seen or 0
 local near=(obs.nearStanding or 0)+(obs.nearDown or 0)
 local engage=near>0 or (obs.alertDistance and obs.alertDistance<=8)
             or (danger.retreat and obs.alertDistance and obs.alertDistance<=10)
 if visible>0 and not old then
    Speech.npcAlert(actor,"SPOTTED")
 end
 if not engage then
    if old then
       cancel(entry,"ameaça encerrada")
       Orders.evaluate(entry.state,{})
       entry.navStatus="RESUMING"
       D.STATES[id]=nil
       Speech.npcAlert(actor,"RESUME")
       Core.log("DEFENSE "..id.." concluida; retomando "..entry.state.requested)
    end
    return false
 end
 if not old then
    cancel(entry,"autodefesa prioridade maxima")
    old={entry=entry,planner=Tactics.new(),lastError=nil,nextAction=0}
    D.STATES[id]=old
    Core.log("DEFENSE "..id.." iniciou; ordem preservada "..entry.state.requested)
 end
 Orders.evaluate(entry.state,{selfThreat=not danger.retreat,mustRetreat=danger.retreat})
 local nowMs=now()
 if danger.retreat and not old.warnedRetreat then
    Speech.npcAlert(actor,danger.unarmed and "UNARMED" or "HORDE",true)
    old.warnedRetreat=true
 elseif not danger.retreat then old.warnedRetreat=false end
 -- A queda so e aceita apos a engine realmente reportar isOnFloor/isProne.
 if old.shoveTarget and nowMs>=old.shoveCheck then
    if zombie(old.shoveTarget) and not fallen(old.shoveTarget) then
       old.planner.failedShoves=(old.planner.failedShoves or 0)+1
    else old.planner.failedShoves=0 end
    old.shoveTarget=nil
 end
 if nowMs<old.nextAction then return true end
 local standing=obs.nearStanding or 0
 local down=obs.nearDown or 0
 local action,tactic=Tactics.plan(old.planner,{
    standing=standing,down=down,alertStanding=obs.standing,
    alertDistance=obs.alertDistance,nearestDistance=obs.nearestDistance,
    nearestDownDistance=obs.nearestDownDistance,visible=obs.visible,
    downVisible=obs.downVisible,mustRetreat=danger.retreat
 })
 if not action then return true end
 -- Keep the existing TimedAction alive during flee/approach/pin.
 -- Cancelling it on each tactical update was the cause of standing still.
 local target=obs.nearest or obs.firstVisible
 if action=="SHOVE" or action=="STOMP" or action=="BACKSTEP" then
    cancel(entry,"troca de fase combate")
 elseif action=="FLEE" and old.lastAction~="FLEE" then
    cancel(entry,"troca de fase combate")
 elseif action=="PIN" and old.lastAction~="PIN" then
    cancel(entry,"troca de fase combate")
 end
 old.lastAction=action
 entry.navStatus=action
 entry.navError=nil
 if action=="SHOVE" then
    local ok,reason=D.shove(actor,obs.nearest)
    old.nextAction=nowMs+650
    if ok then
       old.shoveTarget=obs.nearest
       old.shoveCheck=nowMs+600
       if (old.planner.cycles or 0)<=1 then
          Speech.npcAlert(actor,"COMBAT")
       end
    else
       old.planner.failedShoves=(old.planner.failedShoves or 0)+1
       if reason~=old.lastError then
          Core.log("TACTIC "..id.." shove denied: "..tostring(reason))
          old.lastError=reason
       end
    end
 elseif action=="STOMP" then
    if standing==0 and fallen(obs.nearestDown) then
       local ok,reason=D.hit(actor,obs.nearestDown)
       if not ok and reason~=old.lastError then
          Core.log("TACTIC "..id.." stomp: "..tostring(reason))
          old.lastError=reason
       end
    end
    old.nextAction=nowMs+D.PERIOD_MS
 elseif action=="PIN" then
    local z=obs.nearestDown
    local sq=z and Walking.pickAround and Walking.pickAround(
       math.floor(z:getX()),math.floor(z:getY()),
       math.floor(z:getZ()),actor)
    moveTo(entry,sq,"PIN")
    old.nextAction=nowMs+500
 elseif action=="BACKSTEP" then
    moveAway(entry,target,2,"BACKSTEP")
    old.nextAction=nowMs+1100
 elseif action=="FLEE" then
    local dangerTarget=obs.nearest or obs.nearestDown or obs.firstVisible
    if not Walking.active(id) then
       local moved=moveAway(entry,dangerTarget,4,"FLEE")
       if not moved and old.lastError~="flee blocked" then
          old.lastError="flee blocked"
          Core.log("TACTIC "..id.." fleeing blocked: no walkable retreat tile")
       end
    end
    old.nextAction=nowMs+550
 elseif action=="APPROACH" then
    local z=target
    if z and not Walking.active(id) then
       local sq=Walking.pickAround(math.floor(z:getX()),
          math.floor(z:getY()),math.floor(z:getZ()),actor)
       moveTo(entry,sq,"APPROACH")
    end
    old.nextAction=nowMs+550
 else
    old.nextAction=nowMs+420
 end
 if old.lastLogged~=action or old.lastTactic~=tactic then
    Core.log("TACTIC "..id.." "..tactic.."/"..action..
      " near="..standing.." visible="..(obs.standing or 0)..
      " down="..down.." weapon="..obs.npcWeapon.category..
      " allies="..(obs.allies or 0).." risk="..
      string.format("%.2f",danger.severity))
    old.lastLogged,old.lastTactic=action,tactic
 end
 return true
end
return D
