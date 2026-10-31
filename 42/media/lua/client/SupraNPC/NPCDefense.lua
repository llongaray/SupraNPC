-- SupraNPC: defesa deterministica de curta distancia contra IsoZombie.
-- Inspirado na selecao de alvo de Super Survivors/AttackTask e KnoxSurvivors.
-- Dano: IsoZombie:Hit(HandWeapon, IsoGameCharacter, float, boolean, float)
-- Sempre validar o alvo no instante do golpe; NUNCA atingir IsoPlayer/NPC.
local Core = require("SupraNPC/Constants")
local Orders = require("SupraNPC/Orders")
local Walking = require("SupraNPC/NPCWalking")
local Tactics = require("SupraNPC/CombatTactics")
local StancePolicy = require("SupraNPC/StancePolicy")
local Perception = require("SupraNPC/NPCPerception")
local Speech = require("SupraNPC/NPCSpeech")
local NativeAttack = require("SupraNPC/NPCNativeAttack")
local Navigation = require("SupraNPC/NPCNavigation")
local Territory = require("SupraNPC/Territory")
local MapKnowledge = require("SupraNPC/NPCMapKnowledge")
local D = { RADIUS=4.0, REACH=1.45, PERIOD_MS=1050, MAX_SQUARES=81,
    MAX_OBJECTS=280, MAX_CHASE=4.0, STATES={}, ignored={} }
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
    if not d or d>D.REACH or not canSee(actor,target,d) or
       (getCell and not Navigation.attackAccessible(actor,target)) then
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
    if not ok or fallen(target) or
       (getCell and not Navigation.attackAccessible(actor,target)) then
       return false,"alvo nao empurravel" end
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
    if record and record.entry then
        cancel(record.entry,"combat reset")
        if NativeAttack.release then NativeAttack.release(record.entry.actor) end
    end
    D.STATES[id]=nil
end
function D.clear()
    for id in pairs(D.STATES) do D.reset(id) end
    D.ignored={}
end
local function ignore(id,z,reason)
    if not z then return end
    D.ignored[id]=D.ignored[id] or {}
    D.ignored[id][z]=now()+14000
    Core.log("DEFENSE "..id.." target temporarily inaccessible: "..tostring(reason))
end
-- Low-cost close-quarters pulse while AGGRESSIVE is engaged.
-- Unlike D.update, this does NOT scan the world or rebuild a route.
-- It only attempts the next valid native attack on the already-seen zombie,
-- yielding to any ongoing animation and stopping immediately when it dies.
function D.pulse(entry,player,team)
    local id=entry and entry.profile and entry.profile.id
    local old=id and D.STATES[id]
    if not old or entry.stance~="AGGRESSIVE" or entry.retreating or
       not entry.state or entry.state.active~="SELF_DEFEND" then return false end
    local actor=entry.actor
    local target=old.target
    if not actor or call(actor,"isDead")~=false or not actor.DoAttack or
       not zombie(target) or
       (Navigation.isClimbing and Navigation.isClimbing(id,actor)) then
       return false
    end
    local ms=now()
    -- Each game tick reevaluates whether the next attack can start.
    -- Do not queue a second attack during an existing native animation.
    if ms<(old.nextStrikeAt or 0) or old.lastPulseAt==ms then return false end
    old.lastPulseAt=ms
    local mode=NativeAttack.choose(actor,target)
    if mode~="SHOVE" and mode~="SWING" and mode~="GROUND" then return false end
    if mode=="GROUND" and entry.lastObservation and
       (entry.lastObservation.nearStanding or 0)>0 then return false end
    if call(actor,"isAttacking")==true or
       call(actor,"isAttackStarted")==true then return false end
    if Walking.active(id) then cancel(entry,"alcance de ataque") end
    local ok,reason=NativeAttack.execute(actor,target,mode,player,team)
    -- 35 ms is only for the engine to start an accepted animation,
    -- not an artificial attack/cooldown delay. Lua polling is every tick.
    old.nextStrikeAt=ms+(ok and 35 or
        reason=="attack animation running" and 0 or 60)
    if ok then
        old.nativeRejects=0
        old.lastAction=mode=="GROUND" and "STOMP" or mode
        entry.navStatus=old.lastAction
        old.pulseAccepted=(old.pulseAccepted or 0)+1
        if ms-(old.lastPulseSummary or 0)>=2000 then
            Core.log("COMBAT_PULSE "..id..
                " accepted="..old.pulseAccepted..
                " kind="..tostring(mode)..
                " targetHealth="..tostring(call(target,"getHealth"))..
                " targetDown="..tostring(fallen(target)))
            old.lastPulseSummary=ms
            old.pulseAccepted=0
        end
    elseif reason~="attack animation running" and
        reason~=old.lastPulseError then
        Core.log("COMBAT_PULSE "..id.." "..tostring(mode)..
            " rejected: "..tostring(reason))
        old.lastPulseError=reason
    end
    return ok
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
 entry.lastObservation=obs
 local ignored=D.ignored[id] or {}
 if obs.seen>0 and type(obs.visibleTargets)=="table" then
    local unblocked=nil
    for _,target in ipairs(obs.visibleTargets) do
       if not ignored[target] or ignored[target]<=now() or
          (distance(actor,target) and distance(actor,target)<2 and
              Navigation.attackAccessible(actor,target)) then
           unblocked=target
           ignored[target]=nil
           break
       end
    end
    if not unblocked then
       if old then
           cancel(entry,"target inaccessible")
           Orders.evaluate(entry.state,{})
           D.STATES[id]=nil
       end
       entry.navStatus="TARGET_BLOCKED"
       return false
    elseif obs.nearest and ignored[obs.nearest] and ignored[obs.nearest]>now() then
       -- Do not keep choosing the same blocked enemy when alternatives exist.
       obs.nearest=unblocked
       obs.nearestDistance=distance(actor,unblocked)
       obs.firstVisible=unblocked
    end
 end
 local health=call(call(actor,"getBodyDamage"),"getOverallBodyHealth")
 local danger=Perception.risk(obs,health)
 local visible=obs.seen or 0
 local stance=entry.stance or "DEFENSIVE"
 -- Threat memory prevents FOLLOW resuming while escaping a group
 -- simply because the NPC turned away from the vision cone.
 local memory=false
 local rememberedThreat=nil
 -- Do not retain an unseen group forever: after ~4.5 seconds without
 -- confirmed perception, drop its remembered position. The zombie object
 -- staying loaded/alive alone is not evidence of current danger.
 local recent=old and type(old.lastThreatSeenAt)=="number" and
    (now()-old.lastThreatSeenAt)<4500
 if recent and old and type(old.retreatThreats)=="table" then
    for _,z in ipairs(old.retreatThreats) do
       if zombie(z) then
          local d=Perception.distance(actor,z)
          if d and d<10 then memory=true;rememberedThreat=z;break end
       end
    end
 end
 local policy=StancePolicy.decide(stance,obs,health,danger,memory)
 local engageRange=policy.range
 -- Only real visible danger renews retreat memory, never memory itself.
 local confirmedRetreat=StancePolicy.decide(stance,obs,health,danger,false).retreat
 danger.retreat=policy.retreat
 if memory and policy.retreat and not obs.firstVisible then
    obs.firstVisible=rememberedThreat
 end
 entry.retreating=policy.retreat
 local engage=policy.engage
 -- Nearby enemies still qualify even if the observation exposes only
 -- near-distance fields (e.g. specialized B42 perception adapters).
 if not engage and (obs.nearestDistance and obs.nearestDistance<=engageRange
    or obs.nearestDownDistance and obs.nearestDownDistance<=engageRange) then
    engage=true
 end
 if visible>0 and not old then
    Speech.npcAlert(actor,"SPOTTED")
 end
 if not engage then
    entry.retreating=false
    if old then
       cancel(entry,"ameaça encerrada")
       Orders.evaluate(entry.state,{})
       entry.navStatus="RESUMING"
       D.STATES[id]=nil
       if NativeAttack.release then NativeAttack.release(actor) end
       Speech.npcAlert(actor,"RESUME")
       Core.log("DEFENSE "..id.." concluida; retomando "..entry.state.requested)
    end
    return false
 end
 if not old then
    cancel(entry,"autodefesa prioridade maxima")
    old={entry=entry,planner=Tactics.new(),lastError=nil,nextAction=0}
    D.STATES[id]=old
    Core.log("DEFENSE "..id.." stance="..policy.stance..
        " retreat="..tostring(policy.retreat)..
        "; ordem preservada "..entry.state.requested)
 end
 Orders.evaluate(entry.state,{selfThreat=not danger.retreat,mustRetreat=danger.retreat})
 if danger.retreat then
    -- Refresh the timestamp ONLY when a threat is actually perceived.
    -- A frame driven purely by memory must not renew itself indefinitely.
    if visible>0 and confirmedRetreat then
       old.lastThreatSeenAt=now()
       if type(obs.visibleTargets)=="table" and #obs.visibleTargets>0 then
          old.retreatThreats=obs.visibleTargets
       else old.retreatThreats={obs.nearest or obs.firstVisible or obs.nearestDown} end
    end
 else
    old.retreatThreats=nil
    old.lastThreatSeenAt=nil
 end
 local nowMs=now()
 if type(health)=="number" and health<55 then
    Speech.npcAlert(actor,"HELP")
 end
 if danger.retreat and not old.warnedRetreat then
    Speech.npcAlert(actor,policy.stance=="PASSIVE" and "FLEE" or
        (danger.unarmed and "UNARMED" or "HORDE"),true)
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
    alertDistance=obs.alertDistance,alertDown=obs.down,
    nearestDistance=obs.nearestDistance,
    nearestDownDistance=obs.nearestDownDistance,visible=obs.visible,
    downVisible=obs.downVisible,mustRetreat=danger.retreat,
     melee=obs.npcWeapon.category=="MELEE",engageRange=engageRange,
     stance=policy.stance
 })
 if not action then return true end
 -- Keep the existing TimedAction alive during flee/approach/pin.
 -- Cancelling it on each tactical update was the cause of standing still.
 local target=obs.nearest or obs.firstVisible
 old.target=obs.nearest or obs.nearestDown or obs.firstVisible
 if action=="SHOVE" or action=="SWING" or action=="STOMP" or action=="BACKSTEP" then
    cancel(entry,"troca de fase combate")
 elseif action=="FLEE" and old.lastAction~="FLEE" then
    cancel(entry,"troca de fase combate")
 elseif action=="PIN" and old.lastAction~="PIN" then
    cancel(entry,"troca de fase combate")
 end
 old.lastAction=action
 entry.navStatus=action
 entry.navError=nil
 if action=="SHOVE" or action=="SWING" or action=="STOMP" then
    local hitTarget=action=="STOMP" and obs.nearestDown or obs.nearest
    local valid=hitTarget and (action~="STOMP" or
       (standing==0 and fallen(hitTarget)))
    local ok,reason=false,"no valid target"
    if valid then
       if actor.DoAttack then
          -- Native B42 owns collision/animação. Never double-hit a successful
          -- native attack; retries are paced by animation and time.
          if nowMs < (old.nextStrikeAt or 0) then
              reason="attack cooldown"
          else
              ok,reason=NativeAttack.execute(actor,hitTarget,
                  action=="STOMP" and "GROUND" or action,player,team)
              old.nextStrikeAt=nowMs+(ok and 35 or
                  reason=="attack animation running" and 0 or 60)
          end
       elseif action=="SHOVE" then
          -- Legacy test adapter where the mock has no DoAttack.
          ok,reason=D.shove(actor,hitTarget)
       elseif action=="STOMP" then
          ok,reason=D.hit(actor,hitTarget)
       else reason="native attack unavailable" end
    end
    old.nextAction=nowMs+(stance=="AGGRESSIVE" and 0 or
        (actor.DoAttack and 180 or
        (action=="SHOVE" and 550 or action=="SWING" and 650 or D.PERIOD_MS)))
    if action=="SHOVE" and ok then
       old.shoveTarget=hitTarget
       old.shoveCheck=nowMs+600
       if (old.planner.cycles or 0)<=1 then
          Speech.npcAlert(actor,"COMBAT")
       end
    elseif not ok and reason~="attack animation running" and
        reason~="attack cooldown" then
       if action=="SHOVE" then
          old.planner.failedShoves=(old.planner.failedShoves or 0)+1
       end
       if reason~=old.lastError then
          Core.log("TACTIC "..id.." "..action.." denied: "..tostring(reason))
          old.lastError=reason
       end
    end
 elseif action=="PIN" then
    local z=obs.nearestDown
    if z then
       local sq,reason=Navigation.next(actor,z:getX(),z:getY(),
           z:getZ(),id,Walking.free,1.0)
       if sq then moveTo(entry,sq,"PIN")
       elseif reason~="already near" and reason~="door opened" then
           ignore(id,z,reason)
           entry.navStatus="TARGET_BLOCKED"
       end
    end
    old.nextAction=nowMs+500
 elseif action=="BACKSTEP" then
    moveAway(entry,target,2,"BACKSTEP")
    old.nextAction=nowMs+1100
 elseif action=="FLEE" then
    local dangerTarget=obs.nearest or obs.nearestDown or obs.firstVisible
    if not Walking.active(id) then
       local moved=false
       local knowledge=MapKnowledge.get(player)
       local home=Territory.basePoint(knowledge)
       -- Base designation does not guarantee a zombie-free location.
       if home and not Territory.inside(knowledge,
           actor:getX(),actor:getY(),actor:getZ()) then
           local sq,why=Navigation.next(actor,home.x,home.y,home.z,
               id,Walking.free,2.0,true,true)
           if sq then
               moved=moveTo(entry,sq,"RETURN_BASE")
               if moved then
                  entry.navStatus="FLEE_BASE"
                  if not old.announcedBase then
                      Speech.npcAlert(actor,"BASE")
                      old.announcedBase=true
                  end
               end
           elseif why~="already near" and old.lastBaseError~=why then
               Core.log("TACTIC "..id.." base path: "..tostring(why))
               old.lastBaseError=why
           end
       end
       if not moved then moved=moveAway(entry,dangerTarget,4,"FLEE") end
       if not moved and old.lastError~="flee blocked" then
          old.lastError="flee blocked"
          Core.log("TACTIC "..id.." fleeing blocked: no walkable retreat tile")
       end
    end
    old.nextAction=nowMs+550
 elseif action=="APPROACH" then
    local z=target
    if z and not Walking.active(id) then
       local sq,reason=Navigation.next(actor,z:getX(),z:getY(),
           z:getZ(),id,Walking.free,1.35)
       if sq then moveTo(entry,sq,"APPROACH")
       elseif reason~="already near" and reason~="door opened" then
           ignore(id,z,reason)
           entry.navStatus="TARGET_BLOCKED"
       end
    end
    old.nextAction=nowMs+(stance=="AGGRESSIVE" and 0 or 550)
 else
    old.nextAction=nowMs+(stance=="AGGRESSIVE" and 0 or 420)
 end
 if old.lastLogged~=action or old.lastTactic~=tactic then
    Core.log("TACTIC "..id.." "..tactic.."/"..action..
      " near="..standing.." visible="..(obs.standing or 0)..
      " down="..down.." stance="..stance.." weapon="..obs.npcWeapon.category..
      " allies="..(obs.allies or 0).." risk="..
      string.format("%.2f",danger.severity))
    old.lastLogged,old.lastTactic=action,tactic
 end
 return true
end
return D
