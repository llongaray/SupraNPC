-- SupraNPC: falas do jogador apos ordens. Adaptado de
-- ArayHumanNPCTest/ArayHumanSpeechBubble.lua (sem dependencia de IA).
local Core = require("SupraNPC/Constants")
local Speech = {active={},registered=false, alerts={}}
local function now()
    if getTimestampMs then
        local ok,t=pcall(getTimestampMs)
        if ok and type(t)=="number" then return t end
    end
    return 0
end
local PHRASES={
    FOLLOW={"%s, vem comigo!","%s, me segue!","%s, vamos juntos!"},
    IDLE={"%s, fica aqui!","%s, pode esperar aqui!","%s, aguarda aqui!"},
    GUARD_PLAYER={"%s, guarda esse ponto!","%s, fica de guarda aqui!"},
    GUARD_NPC={"%s, protege essa posicao!","%s, vigia esse lugar!"},
    PASSIVE={"%s, evita confrontos!","%s, postura passiva!"},
    DEFENSIVE={"%s, fica na defensiva!","%s, toma cuidado!"},
    AGGRESSIVE={"%s, fica em alerta!","%s, postura agressiva!"}
}
local count=0
function Speech.compose(name,cmd,option,success)
    local short=tostring(name or "Pessoal")
    if #short>24 then short=short:sub(1,24) end
    if success==false then return short..", nao consegui dar essa ordem!" end
    local key=cmd=="STANCE" and option or
        (cmd=="GUARD" and (option=="PLAYER" and "GUARD_PLAYER" or "GUARD_NPC") or cmd)
    local phrases=PHRASES[key]
    if not phrases then return short..", atencao!" end
    count=count+1
    return string.format(phrases[(count-1)%#phrases+1],short)
end
local function show(actor,message)
    if not actor or not message or message=="" then return end
    local at=now()
    for _,r in ipairs(Speech.active) do
        if r.actor==actor then
            if #r.queue>=2 then table.remove(r.queue,1) end
            r.queue[#r.queue+1]=message
            return
        end
    end
    Speech.active[#Speech.active+1]={
        actor=actor,text=message,created=at,expires=at+math.max(2600,
            math.min(8000,#message*90)),queue={}
    }
    Core.log("SPEECH: "..message)
end
function Speech.playerCommand(player,name,cmd,option,success)
    if not player then return end
    show(player,Speech.compose(name,cmd,option,success))
end
local NPC_ANSWERS={
    FOLLOW={"Estou indo!","Estou com voce!"},
    IDLE={"Entendido, vou esperar!","Vou ficar aqui."},
    GUARD={"Vou vigiar esse local.","Deixa comigo!"},
    PASSIVE={"Vou evitar problemas."},
    DEFENSIVE={"Fico na defensiva."},
    AGGRESSIVE={"Certo, estarei em alerta."}
}
local WARNINGS={
    SPOTTED={"Zumbis la na frente!","Vi mortos por ali!"},
    HELP={"Socorro! Preciso de ajuda!","Me ajuda aqui!"},
    HORDE={"Tem muitos! Foge!","Nao vamos aguentar, corre!"},
    UNARMED={"Estamos sem armas! Recuem!","Sem armas, melhor fugir!"},
    FLEE={"Vou recuar!","Corram! Vou sair daqui!"},
    COMBAT={"Deixa que eu seguro esse!","Vou derrubar ele!"},
    RESUME={"Tudo limpo. Voltando!","Vou seguir a ordem!"}
}
local lastSaid={}
function Speech.npcReply(actor,cmd,option,success)
    if not actor then return end
    local key=cmd=="STANCE" and option or cmd
    local responses=NPC_ANSWERS[key]
    if success==false then show(actor,"Nao consigo cumprir essa ordem!") return end
    if not responses then show(actor,"Entendido!") return end
    local n=(lastSaid[actor] or 0)+1
    lastSaid[actor]=n
    show(actor,responses[(n-1)%#responses+1])
end
function Speech.npcAlert(actor,kind,force)
    if not actor or not WARNINGS[kind] then return false end
    local when=now()
    local entry=Speech.alerts[actor]
    if not entry then entry={} Speech.alerts[actor]=entry end
    if not force and entry[kind] and when-entry[kind]<11000 then return false end
    entry[kind]=when
    local options=WARNINGS[kind]
    local index=math.floor(when/11000)%#options+1
    show(actor,options[index])
    return true
end
local function project(actor)
    local x,y,z=actor:getX(),actor:getY(),actor:getZ()
    if isoToScreenX and isoToScreenY then
        local ok,sx,sy=pcall(function()
            return isoToScreenX(0,x,y,z+0.9),isoToScreenY(0,x,y,z+0.9)
        end)
        if ok and sx and sy then return sx,sy end
    end
    if actor.getScreenX and actor.getScreenY then
        local ok,sx,sy=pcall(function()
            return actor:getScreenX(),actor:getScreenY()-75
        end)
        if ok then return sx,sy end
    end
end
function Speech.draw()
    if #Speech.active==0 then return end
    local at=now()
    local manager=getTextManager and getTextManager()
    local font=UIFont and UIFont.Small
    for i=#Speech.active,1,-1 do
        local r=Speech.active[i]
        if at>=r.expires or not r.actor or
           (r.actor.isDead and r.actor:isDead()) then
            if #r.queue>0 and r.actor then
                r.text=table.remove(r.queue,1)
                r.created=at
                r.expires=at+math.max(2600,math.min(8000,#r.text*90))
            else
                table.remove(Speech.active,i)
            end
        elseif manager and font then
            local ok,err=pcall(function()
                local sx,sy=project(r.actor)
                if not sx or not sy then return end
                local width=manager:MeasureStringX(font,r.text)
                local x=sx-width/2
                manager:DrawString(font,x+1,sy+1,r.text,0,0,0,0.92)
                manager:DrawString(font,x,sy,r.text,1,1,0.86,1)
            end)
            if not ok and not Speech.drawError then
                Speech.drawError=true
                Core.log("Falha bubble de fala: "..tostring(err))
            end
        end
    end
end
function Speech.clear()
    Speech.active={}
    Speech.alerts={}
    lastSaid={}
end
if Events and Events.OnPostUIDraw then
    Events.OnPostUIDraw.Add(Speech.draw)
    Speech.registered=true
elseif Events and Events.OnPostRender then
    Events.OnPostRender.Add(Speech.draw)
    Speech.registered=true
end
return Speech
