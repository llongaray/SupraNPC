-- SupraNPC: defesa deterministica de curta distancia contra IsoZombie.
-- Inspirado na selecao de alvo de Super Survivors/AttackTask e KnoxSurvivors.
-- Dano: IsoZombie:Hit(HandWeapon, IsoGameCharacter, float, boolean, float)
-- Sempre validar o alvo no instante do golpe; NUNCA atingir IsoPlayer/NPC.
local Core = require("SupraNPC/Constants")
local Orders = require("SupraNPC/Orders")
local Walking = require("SupraNPC/NPCWalking")
local D = { RADIUS=3.2, REACH=1.45, PERIOD_MS=1050, MAX_SQUARES=49,
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
        return target:Hit(weapon,actor,damage,false,1.0)
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
function D.reset(id)
    local record=D.STATES[id]
    if record and record.entry then cancel(record.entry,"combat reset") end
    D.STATES[id]=nil
end
function D.clear()
    for id in pairs(D.STATES) do D.reset(id) end
end
function D.update(entry)
    local id=entry and entry.profile and entry.profile.id
    if not id then return false end
    local actor=entry.actor
    local old=D.STATES[id]
    if call(actor,"isDead")~=false then
        if old then D.reset(id) end
        return false
    end
    local target=D.scan(actor)
    if not target then
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
        -- A ordem solicitada permanece requested; só active é interrompido.
        cancel(entry,"autodefesa prioridade maxima")
        Orders.evaluate(entry.state,{selfThreat=true})
        old={entry=entry,target=target,nextHit=0,lastError=nil,lastChase=0}
        D.STATES[id]=old
        Core.log("DEFENSE "..id.." interrompeu "..entry.state.requested)
    end
    if old.target~=target then
        cancel(entry,"troca de zumbi")
        old.target=target
    end
    local dist=distance(actor,target)
    if not dist then return true end
    entry.navStatus="DEFENDING"
    local currentWeapon=weaponOf(actor)
    local actualReach=call(currentWeapon,"getMaxRange")
    if not finite(actualReach) then actualReach=D.REACH end
    actualReach=math.min(D.REACH,math.max(0.6,actualReach))
    if dist<=actualReach then
        cancel(entry,"alcance de ataque")
        if now()>=old.nextHit then
            old.nextHit=now()+D.PERIOD_MS
            local ok,why=D.hit(actor,target)
            if not ok and old.lastError~=why then
                old.lastError=why
                Core.log("DEFENSE "..id..": "..tostring(why))
            end
        end
    elseif dist<=D.MAX_CHASE and not Walking.active(id) then
        -- Aproximação limitada: nao perseguir zumbis alem do raio imediato.
        local bx,by,bz=math.floor(target:getX()),
            math.floor(target:getY()),math.floor(target:getZ())
        local square=Walking.pickAround(bx,by,bz,actor)
        if square then
            local ok,reason=Walking.start(id,actor,square)
            if not ok and old.lastError~=reason then
                Core.log("DEFENSE "..id.." aproximação falhou "..tostring(reason))
                old.lastError=reason
            end
        end
    end
    return true
end
return D
