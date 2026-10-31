-- SupraNPC: defesa deterministica de curta distancia contra IsoZombie.
-- Inspirado na selecao de alvo de Super Survivors/AttackTask e KnoxSurvivors.
-- Dano: IsoZombie:Hit(HandWeapon, IsoGameCharacter, float, boolean, float)
-- Sempre validar o alvo no instante do golpe; NUNCA atingir IsoPlayer/NPC.
local Core = require("SupraNPC/Constants")
local Orders = require("SupraNPC/Orders")
local Walking = require("SupraNPC/NPCWalking")
local Tactics = require("SupraNPC/CombatTactics")
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
    if not actor or call(actor,"isDead")~=false then return nil end
    local cell=getCell and getCell()
    if not cell then return nil end
    local x,y,z=call(actor,"getX"),call(actor,"getY"),call(actor,"getZ")
    if not finite(x) or not finite(y) or not finite(z) then return nil end
    local bx,by,bz=math.floor(x),math.floor(y),math.floor(z)
    local best,bestScore,seen=nil,math.huge,0
    -- Apenas squares carregados ao redor do NPC, sem criar chunks nem zumbis.
    for ox=-3,3 do
        for oy=-3,3 do
            local sq=call(cell,"getGridSquare",bx+ox,by+oy,bz)
            local objects=call(sq,"getMovingObjects")
            local count=call(objects,"size")
            if type(count)=="number" and count>=0 and count<=32 then
                for i=0,count-1 do
                    seen=seen+1
                    if seen>D.MAX_OBJECTS then return best end
                    local target=call(objects,"get",i)
                    if zombie(target) and call(target,"getCurrentSquare")==sq then
                        local d=distance(actor,target)
                        if d and d<=D.RADIUS and canSee(actor,target,d) then
                            local direct=call(target,"getTarget")==actor
                            local score=d-(direct and 1.3 or 0)
                            if score<bestScore then
                                best,bestScore=target,score
                            end
                        end
                    end
                end
            end
        end
    end
    return best
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
local function fallen(target)
    if not zombie(target) or call(target,"isGettingUp")==true or
       call(target,"isCrawling")==true then return false end
    return call(target,"isOnFloor")==true or call(target,"isProne")==true
end
local function allyNearby(actor,player,team)
    local function close(candidate)
        if not candidate or candidate==actor or call(candidate,"isDead")~=false then
            return false end
        local d=distance(actor,candidate)
        return d and d<=4.0
    end
    if close(player) then return true end
    if type(team)=="table" then
        for _, e in pairs(team) do
            if type(e)=="table" and close(e.actor) then return true end
        end
    end
    return false
end
function D.observe(actor,player,team)
    local obs={standing=0,down=0,nearest=nil,nearestDown=nil,
        nearestDistance=nil,nearestDownDistance=nil,visible=false,
        downVisible=false,ally=allyNearby(actor,player,team)}
    local x,y,z=call(actor,"getX"),call(actor,"getY"),call(actor,"getZ")
    local cell=getCell and getCell()
    if not cell or not finite(x) or not finite(y) or not finite(z) then
        return obs end
    local bx,by,bz=math.floor(x),math.floor(y),math.floor(z)
    local inspected,seen=0,{}
    for ox=-4,4 do
        for oy=-4,4 do
            local sq=call(cell,"getGridSquare",bx+ox,by+oy,bz)
            local objects=call(sq,"getMovingObjects")
            local n=call(objects,"size")
            if type(n)=="number" and n>=0 and n<=32 then
                for i=0,n-1 do
                    inspected=inspected+1
                    if inspected>D.MAX_OBJECTS then return obs end
                    local target=call(objects,"get",i)
                    if target and not seen[target] then
                        seen[target]=true
                        if zombie(target) and call(target,"getCurrentSquare")==sq then
                            local dist=distance(actor,target)
                            if dist and dist<=D.RADIUS then
                                local down=fallen(target)
                                if down then
                                    obs.down=obs.down+1
                                    if not obs.nearestDownDistance or
                                       dist<obs.nearestDownDistance then
                                        obs.nearestDown=target
                                        obs.nearestDownDistance=dist
                                        obs.downVisible=canSee(actor,target,dist)
                                    end
                                else
                                    obs.standing=obs.standing+1
                                    if not obs.nearestDistance or
                                       dist<obs.nearestDistance then
                                        obs.nearest=target
                                        obs.nearestDistance=dist
                                        obs.visible=canSee(actor,target,dist)
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    return obs
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
    local roll=ZombRand and ZombRand(100)
    if not finite(roll) then return false,"RNG do jogo indisponivel" end
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
    local o=D.observe(actor,player,team)
    if o.standing+o.down==0 then
        if old then
            cancel(entry,"ameaça encerrada")
            Orders.evaluate(entry.state,{})
            entry.navStatus="RESUMING"
            D.STATES[id]=nil
            Core.log("DEFENSE "..id.." concluida; retomando "..entry.state.requested)
        end
        return false
    end
    if not old then
        cancel(entry,"autodefesa prioridade maxima")
        Orders.evaluate(entry.state,{selfThreat=true})
        old={entry=entry,planner=Tactics.new(),lastError=nil,nextAction=0,
            lastTarget=nil}
        D.STATES[id]=old
        Core.log("DEFENSE "..id.." interrompeu "..entry.state.requested)
    end
    local timestamp=now()
    -- Evita enfileirar ou atacar a cada frame.
    if timestamp<old.nextAction then return true end
    local action,tactic=Tactics.plan(old.planner,o)
    if not action then return true end
    local target=o.nearest
    if action=="PIN" or action=="STOMP" then target=o.nearestDown end
    if action=="SHOVE" or action=="STOMP" or action=="BACKSTEP" or
       action=="FLEE" or action=="PIN" then
        cancel(entry,"troca de fase combate")
    end
    entry.navStatus=action
    if action=="SHOVE" then
        local ok,reason=D.shove(actor,o.nearest)
        old.nextAction=timestamp+900
        if not ok and reason~=old.lastError then
            Core.log("TACTIC "..id.." shove denied: "..tostring(reason))
            old.lastError=reason
        end
    elseif action=="STOMP" then
        -- Somente golpear no chao SE TODOS os zumbis proximos
        -- realmente estiverem caidos (nao basta uma ordem bem sucedida).
        if o.standing==0 and fallen(target) then
            local ok,reason=D.hit(actor,target)
            if not ok and reason~=old.lastError then
                Core.log("TACTIC "..id.." stomp: "..tostring(reason))
                old.lastError=reason
            end
        end
        old.nextAction=timestamp+D.PERIOD_MS
    elseif action=="PIN" then
        -- O movimento precisa levar o NPC a < 0.92 tile do corpo.
        -- Nao teletransporta nem muda artificialmente isOnFloor.
        local sq=target and Walking.pickAround and Walking.pickAround(
            math.floor(target:getX()),math.floor(target:getY()),
            math.floor(target:getZ()),actor)
        moveTo(entry,sq,"PIN")
        old.nextAction=timestamp+800
    elseif action=="BACKSTEP" then
        moveAway(entry,o.nearest,2,"BACKSTEP")
        old.nextAction=timestamp+950
    elseif action=="FLEE" then
        moveAway(entry,o.nearest or o.nearestDown,4,"FLEE")
        old.nextAction=timestamp+1100
    elseif action=="APPROACH" then
        local z=o.nearest
        local sq=z and Walking.pickAround and Walking.pickAround(
            math.floor(z:getX()),math.floor(z:getY()),math.floor(z:getZ()),actor)
        moveTo(entry,sq,"APPROACH")
        old.nextAction=timestamp+850
    else
        old.nextAction=timestamp+650
    end
    if old.lastLogged~=action or old.lastTactic~=tactic then
        Core.log("TACTIC "..id.." "..tactic.."/"..action..
            " standing="..o.standing.." down="..o.down..
            " ally="..tostring(o.ally))
        old.lastLogged,old.lastTactic=action,tactic
    end
    return true
end
return D
