-- SupraNPC B42: controlled reconstruction of extra IsoPlayer on save reload.
-- The game does not reliably serialize secondary IsoPlayer instances. Save
-- only serializable profile state; rebuild the *same profile ID* if missing.
-- No silent recovery for old saves without a last known position: manual only.
local Core=require("SupraNPC/Constants")
local Adapter=require("SupraNPC/SpawnAdapter")
local Controller=require("SupraNPC/NPCController")
local Roster=require("SupraNPC/Roster")
local Recovery={attempts={},noticed={},graceTicks=270,maximumDistance=25}
local function call(o,name,...)
    if not o then return nil end
    local args={...}
    local ok,value=pcall(function()
        if o[name] then return o[name](o,unpack(args)) end
    end)
    if ok then return value end
end
local function position(actor)
    local x,y,z=call(actor,"getX"),call(actor,"getY"),call(actor,"getZ")
    if type(x)=="number" and type(y)=="number" and type(z)=="number" then
        return {x=x,y=y,z=z}
    end
end
local function validData(data)
    if not data or not data.roster or not data.roster.profiles then
        return false
    end
    return Roster.validate(data.roster,true)==true
end
local function getProfile(data,id)
    if not validData(data) then return nil end
    for _,profile in ipairs(data.roster.profiles) do
        if profile.id==id then return profile end
    end
end
local function cell()
    return type(getCell)=="function" and getCell() or nil
end
local function locate(id,profile)
    local actor=Adapter.get(id)
    if actor and call(actor,"isDead")==true then
        profile.deceased=true
        profile.humanSpawned=false
        Core.log("RECOVERY: NPC morto detectado; nao recuperar "..id)
        return nil
    end
    if actor then return actor end
    local existing=Adapter.findExisting(cell(),id)
    if existing and call(existing,"isDead")==true then
        profile.deceased=true
        profile.humanSpawned=false
        Core.log("RECOVERY: corpo encontrado; bloquear recriacao "..id)
        return nil
    end
    if existing then
        Adapter.attach(id,existing)
        Controller.attach(profile,existing)
        Core.log("RECOVERY: existente reanexado "..id)
        return existing
    end
end
function Recovery.reset()
    Recovery.attempts={}
    Recovery.noticed={}
end
-- Called every 90 game ticks; only primitive data is saved in ModData.
function Recovery.track(data)
    if not validData(data) then return end
    for _,p in ipairs(data.roster.profiles) do
        if p.humanSpawned and not p.deceased then
            local actor=Adapter.get(p.id)
            if actor then
                if call(actor,"isDead")==true then
                    p.deceased=true
                    p.humanSpawned=false
                    Core.log("RECOVERY: NPC morreu, bloqueada recriacao "..p.id)
                else
                    local pos=position(actor)
                    if pos then p.lastKnown=pos end
                end
            end
        end
    end
end
function Recovery.restore(player,data,id,manual)
    if not Core.isSolo() or not Core.EXPERIMENTAL_SPAWN or
       Adapter.MODE~="iso_player" then return false,"engine inativa" end
    local profile=getProfile(data,id)
    if not profile or data.spawnStatus~="human_spawned" or
       profile.humanSpawned~=true then return false,"ficha nao disponivel" end
    if profile.deceased then return false,"NPC morto; sem ressurreicao" end
    if locate(id,profile) then
        return true,"NPC ja existe"
    end
    -- locate may have discovered a dead IsoPlayer in a loaded square.
    if profile.deceased or profile.humanSpawned~=true then
        return false,"NPC morto; sem ressurreicao"
    end
    if Recovery.attempts[id] then
        return false,"recuperacao ja tentada nesta sessao"
    end
    local last=profile.lastKnown
    if not manual then
        if not last then return false,"save antigo: recuperacao manual necessaria" end
        local here=position(player)
        if not here or math.floor(here.z)~=math.floor(last.z) or
           (here.x-last.x)^2+(here.y-last.y)^2 >
               Recovery.maximumDistance*Recovery.maximumDistance then
            return false,"ultimo local longe ou em outro andar"
        end
        local world=cell()
        local square=world and call(world,"getGridSquare",
            math.floor(last.x),math.floor(last.y),math.floor(last.z))
        if not square then return false,"area do ultimo local nao carregada" end
    end
    -- Strict one-per-session restoration prevents infinite respawn loops.
    -- Adapter.spawn itself checks existing actor matching the same ID.
    Recovery.attempts[id]=true
    local ok,actor,err=pcall(Adapter.spawn,player,profile,{})
    if not ok or not actor then
        local reason=ok and err or actor
        Core.log("RECOVERY: falha "..id..": "..tostring(reason))
        return false,tostring(reason)
    end
    profile.humanSpawned=true
    profile.recoveryCount=(tonumber(profile.recoveryCount) or 0)+1
    local pos=position(actor)
    if pos then profile.lastKnown=pos end
    Controller.attach(profile,actor)
    Adapter.restoreOwner(player)
    Core.log("RECOVERY: IsoPlayer recriado "..id..
        " tentativa="..tostring(profile.recoveryCount)..
        " modo="..(manual and "manual" or "automatico"))
    return true,"NPC recuperado"
end
function Recovery.update(player,data,ticks)
    if not validData(data) or data.spawnStatus~="human_spawned" then return end
    Recovery.track(data)
    for _,p in ipairs(data.roster.profiles) do
        if p.humanSpawned and not p.deceased and not locate(p.id,p) then
            if not Recovery.noticed[p.id] then
                Core.log("RECOVERY: "..p.id..
                    " ausente da lista ativa; ultima posicao="..
                    (p.lastKnown and "registrada" or "desconhecida"))
                Recovery.noticed[p.id]=true
            end
            if ticks>=Recovery.graceTicks and p.lastKnown and
               not Recovery.attempts[p.id] then
                local ok,reason=Recovery.restore(player,data,p.id,false)
                if ok then Recovery.noticed[p.id]=nil
                elseif reason and reason~="area do ultimo local nao carregada" and
                       reason~="ultimo local longe ou em outro andar" then
                    -- An unrecoverable condition should not spam logs.
                    Recovery.attempts[p.id]=true
                    Core.log("RECOVERY: automatico aguardando intervencao: "..
                        tostring(reason))
                end
            end
        end
    end
end
function Recovery.manual(player,data,id)
    return Recovery.restore(player,data,id,true)
end
Core.Recovery=Recovery
return Recovery
