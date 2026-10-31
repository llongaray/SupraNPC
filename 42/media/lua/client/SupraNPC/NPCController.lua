-- SupraNPC - ordens deterministicas; movimento B42 via TimedAction nativa.
-- Referencia: ArayHumanNPCTest/ArayHumanCommands.lua + ArayHumanWalking.lua.
local Core = require("SupraNPC/Constants")
local Orders = require("SupraNPC/Orders")
local Adapter = require("SupraNPC/SpawnAdapter")
local Walking = require("SupraNPC/NPCWalking")
local Defense = require("SupraNPC/NPCDefense")
local Navigation = require("SupraNPC/NPCNavigation")
local Controller = {entries={},ticks=0}
local STANCES = {PASSIVE=true, DEFENSIVE=true, AGGRESSIVE=true}
local function call(obj,method,...)
    if not obj then return nil end
    local args={...}
    local ok,res=pcall(function()
        if obj[method] then return obj[method](obj,unpack(args)) end
    end)
    if ok then return res end
    return nil
end
local function finite(n)
    return type(n)=="number" and n==n and n~=math.huge and n~=-math.huge
end
local function distance(ax,ay,bx,by)
    return math.sqrt((ax-bx)^2+(ay-by)^2)
end
local function persist(entry)
    entry.profile.commandState=Orders.snapshot(entry.state)
    entry.profile.order=entry.state.requested
    entry.profile.stance=entry.stance
    local md=call(entry.actor,"getModData")
    if md then
        md.SupraNPC_CommandState=Orders.snapshot(entry.state)
        md.SupraNPC_Order=entry.state.requested
        md.SupraNPC_Stance=entry.stance
    end
end
function Controller.clear()
    Defense.clear()
    for id in pairs(Controller.entries) do
        Walking.cancel(id,"limpeza")
        Navigation.clear(id)
    end
    Controller.entries,Controller.ticks={},0
end
function Controller.attach(profile,actor)
    if not profile or not actor or type(profile.id)~="string" or
       Adapter.get(profile.id)~=actor then return false end
    if Controller.entries[profile.id] and
       Controller.entries[profile.id].actor==actor then return true end
    local md=call(actor,"getModData")
    if not md or md.SupraNPC_ID~=profile.id or
       md.SupraNPC_IsNPC~=true then return false end
    Walking.cancel(profile.id,"reattach")
    local saved=profile.commandState or md.SupraNPC_CommandState
    local state=Orders.restore(saved or {requested=profile.order or "FOLLOW"})
    local stance=STANCES[profile.stance] and profile.stance or "DEFENSIVE"
    Controller.entries[profile.id]={
        actor=actor,profile=profile,state=state,stance=stance,
        navError=nil,navStatus="READY",navTries=0,
        navDisabled=false,nextRequest=0,anchor=nil,lastLog=0
    }
    persist(Controller.entries[profile.id])
    return true
end
function Controller.get(id) return Controller.entries[id] end
function Controller.order(id,command,player,which)
    local entry=Controller.entries[id]
    if not entry then return false,"NPC nao registrado" end
    if command~="FOLLOW" and command~="IDLE" and command~="GUARD" then
        return false,"Comando nao disponivel"
    end
    if command=="GUARD" then
        local source=which=="PLAYER" and player or entry.actor
        if not source then return false,"Alvo nao disponivel" end
        local x,y,z=call(source,"getX"),call(source,"getY"),call(source,"getZ")
        if not finite(x) or not finite(y) or not finite(z) then
            return false,"Posicao invalida"
        end
        local ok,reason=Orders.setGuardPoint(entry.state,
            math.floor(x),math.floor(y),math.floor(z))
        if not ok then return false,reason end
    end
    -- Ordem substitui somente a acao pertencente a ESTE NPC, nunca a do player.
    -- O jogador pode alterar requested durante ataque; defesa continua
    -- com prioridade e a nova ordem sera retomada depois da luta.
    if not Defense.STATES[id] then Walking.cancel(id,"nova ordem") end
    local ok,reason=Orders.set(entry.state,command)
    if not ok then return false,reason end
    entry.navError=nil
    entry.navTries=0
    entry.navDisabled=false
    Navigation.clear(id)
    entry.anchor=nil
    entry.nextRequest=0
    entry.navStatus=Defense.STATES[id] and "DEFENDING" or
        (command=="IDLE" and "WAITING" or "READY")
    persist(entry)
    Core.log("ORDER "..id.." "..command.." status="..entry.navStatus)
    return true
end
function Controller.stance(id,stance)
    local entry=Controller.entries[id]
    if not entry then return false,"NPC nao registrado" end
    if not STANCES[stance] then return false,"Postura invalida" end
    entry.stance=stance
    persist(entry)
    Core.log("STANCE "..id.." "..stance.." intercept range updated")
    return true
end
local function fail(entry,reason)
    entry.navTries=entry.navTries+1
    entry.navError=tostring(reason)
    entry.navStatus="FAILED"
    entry.anchor=nil
    entry.nextRequest=Controller.ticks + math.min(300,90*entry.navTries)
    Core.log("NAV "..entry.profile.id.." falha: "..entry.navError)
    if entry.navTries>=3 then
        entry.navDisabled=true
        entry.navStatus="BLOCKED"
        Core.log("NAV "..entry.profile.id.." bloqueado apos 3 tentativas")
    end
end
local function walk(entry,square,target)
    local id=entry.profile.id
    local ok,why=Walking.start(id,entry.actor,square,function(result)
        -- Nao apagar nova ordem caso callback seja disparado em cancelamento.
        if result=="substituido" or result=="nova ordem" or
           result=="reattach" or result=="limpeza" or
           result=="aguardar" or result=="proximo do jogador" or
           result=="ponto alcancado" or result=="entidade perdida" or
           result=="autodefesa prioridade maxima" or
           result=="alcance de ataque" or result=="troca de zumbi" or
           result=="ameaça encerrada" or result=="combat reset" or
           result=="troca de fase combate" or
           result=="player moved" then return end
        if result=="sucesso" then
            entry.navStatus=entry.state.requested=="GUARD" and "HOLD" or "ARRIVED"
            entry.navError=nil
            entry.navTries=0
        elseif entry.state.active=="FOLLOW" or entry.state.active=="GUARD" then
            fail(entry,result)
        end
    end)
    if not ok then fail(entry,why);return end
    entry.navStatus="MOVING"
    entry.navError=nil
    entry.anchor=target
    Core.log("NAV "..id.." ordem "..entry.state.requested..
        " via ISWalkToTimedAction")
end
local function tickFollow(entry,player)
    local actor=entry.actor
    local px,py,pz=call(player,"getX"),call(player,"getY"),call(player,"getZ")
    local ax,ay,az=call(actor,"getX"),call(actor,"getY"),call(actor,"getZ")
    if not finite(px) or not finite(py) or not finite(pz) or
       not finite(ax) or not finite(ay) or not finite(az) then return end
    if math.floor(az)~=math.floor(pz) then
        fail(entry,"jogador em outro andar");return
    end
    if distance(ax,ay,px,py)<=Core.DEFAULT_FOLLOW_DISTANCE then
        if Walking.active(entry.profile.id) then
            Walking.cancel(entry.profile.id,"proximo do jogador")
        end
        entry.navStatus="NEAR"
        entry.anchor=nil
        entry.navTries=0
        return
    end
    if Walking.active(entry.profile.id) then
        local deviation=entry.anchor and
            distance(px,py,entry.anchor.x,entry.anchor.y) or 999
        if deviation<=1.25 then
            entry.navStatus="MOVING"
            return
        end
        Walking.cancel(entry.profile.id,"player moved")
    end
    -- Walk in loaded, accessible steps; never choose a tile behind a closed
    -- window, locked door, wall or impassable fence.
    local square,reason=Navigation.next(actor,px,py,pz,
        entry.profile.id,Walking.free,Core.DEFAULT_FOLLOW_DISTANCE)
    if not square then
        if reason=="already near" or reason=="door opened" then
            entry.navStatus=reason=="door opened" and "OPEN_DOOR" or "NEAR"
        else
            entry.navStatus="REPATH"
            entry.navError=tostring(reason)
        end
        return
    end
    walk(entry,square,{x=px,y=py})
end
local function tickGuard(entry)
    local actor=entry.actor
    local point=entry.state.guardPoint
    if not point then return end
    local ax,ay,az=call(actor,"getX"),call(actor,"getY"),call(actor,"getZ")
    if not finite(ax) or not finite(ay) or not finite(az) then return end
    if math.floor(az)~=point.z then
        fail(entry,"ponto de guarda em outro andar");return
    end
    if distance(ax,ay,point.x+0.5,point.y+0.5)<=1.3 then
        if Walking.active(entry.profile.id) then
            Walking.cancel(entry.profile.id,"ponto alcancado")
        end
        entry.navStatus="HOLD"
        entry.navTries=0
        return
    end
    if Walking.active(entry.profile.id) then
        entry.navStatus="MOVING"
        return
    end
    local cell=getCell and getCell()
    local square=cell and call(cell,"getGridSquare",point.x,point.y,point.z)
    if not Walking.free(square,actor) then
        square=Walking.pickAround(point.x,point.y,point.z,actor)
    end
    if not square then fail(entry,"ponto de guarda bloqueado");return end
    walk(entry,square,{x=point.x,y=point.y})
end
function Controller.update(player)
    if not Core.isSolo() then return end
    Controller.ticks=Controller.ticks+1
    Walking.update()
    if not player or Controller.ticks%15~=0 then return end
    for id,entry in pairs(Controller.entries) do
        if Adapter.get(id)==entry.actor and
           call(entry.actor,"isDead")~=true then
            -- Defesa passa antes de QUALQUER ordem manual; nao apaga requested.
            local fighting=Defense.update(entry,player,Controller.entries)
            if fighting then
                entry.navStatus=entry.navStatus or "DEFENDING"
            elseif entry.state.active=="IDLE" then
                if Walking.active(id) then Walking.cancel(id,"aguardar") end
                entry.navStatus="WAITING"
            elseif not entry.navDisabled and Controller.ticks>=entry.nextRequest then
                if entry.state.active=="FOLLOW" then tickFollow(entry,player)
                elseif entry.state.active=="GUARD" then tickGuard(entry) end
            end
        else
            Walking.cancel(id,"entidade perdida")
            entry.navStatus="OFFLINE"
        end
    end
end
return Controller
