-- SupraNPC: bootstrap de equipe e spawn humano B42.13.1 (experimental).
-- Adota IsoPlayer.new + render manual do ArayHumanNPCTest. SEM IsoZombie.
local Core = require("SupraNPC/Constants")
local Roster = require("SupraNPC/Roster")
local TeamSetup = require("SupraNPC/TeamSetup")
local TeamFlow = require("SupraNPC/TeamFlow")
local Adapter = require("SupraNPC/SpawnAdapter")
local Renderer = require("SupraNPC/Renderer")
local Controller = require("SupraNPC/NPCController")
local NPCUI = require("SupraNPC/NPCUI")
local MapKnowledge = require("SupraNPC/NPCMapKnowledge")

local Boot = { ticks = 0, lastNotice = nil, interval = 90, maxRetries = 3 }

local function currentPlayer()
    return getSpecificPlayer and getSpecificPlayer(0) or nil
end

local function storeNewRoster(player)
    if not player or not player.getModData or not Core.pendingRoster then return false end
    local valid, reason = Roster.validate(Core.pendingRoster, true)
    if not valid then
        Core.log("Equipe incompleta; nao persistindo: " .. tostring(reason))
        return false
    end
    local modData = player:getModData()
    if modData.SupraNPC then
        Core.log("Save ja possui equipe; nao copiar fichas novamente")
        Core.pendingRoster = nil
        return false
    end
    local roster = Roster.copy(Core.pendingRoster)
    local status = roster.count > 0 and "pending_human" or "no_companions"
    modData.SupraNPC = {
        schema = 3, roster = roster,
        spawnedCount = 0, spawnAttempts = 0,
        spawnStatus = status, humanEngine = "IsoPlayer",
        spawnAttempted = false
    }
    Core.pendingRoster = nil
    Core.log("Equipe no save: " .. tostring(roster.count) ..
        " NPC(s); spawnStatus=" .. status)
    return true
end

local function migrateDisabledRoster(data)
    if not data or not data.roster then return end
    -- Migrar apenas saves 0.1.4-0.1.6 com fichas e SEM qualquer spawn.
    -- Nunca reviver proxies de 0.1.3, mesmo que estejam em save antigo.
    if data.spawnStatus == "disabled" and
       (data.spawnedCount or 0) == 0 and
       (data.spawnAttempts or 0) == 0 and
       data.spawnAttempted == false then
        local valid = Roster.validate(data.roster, true)
        if valid then
            data.spawnStatus = data.roster.count > 0 and
                "pending_human" or "no_companions"
            data.schema = 3
            data.humanEngine = "IsoPlayer"
            Core.log("Migracao segura do roster antigo para spawn humano")
        end
    end
end

local function spawnStep(player, data)
    if not Core.EXPERIMENTAL_SPAWN or Adapter.MODE ~= "iso_player" then
        return
    end
    if not data or not data.roster or
        (data.spawnStatus ~= "pending_human" and
         data.spawnStatus ~= "retry_human") then return end
    local valid, reason = Roster.validate(data.roster, true)
    if not valid then
        data.spawnStatus = "blocked_invalid_roster"
        Core.log("Spawn humano bloqueado: " .. tostring(reason))
        return
    end
    if data.spawnAttempts >= Boot.maxRetries then
        data.spawnStatus = "blocked_human"
        Core.log("Spawn humano bloqueado apos tentativas; ver console.txt")
        return
    end
    data.spawnAttempts = data.spawnAttempts + 1
    local reserved, failures, count = {}, {}, 0
    for index, profile in ipairs(data.roster.profiles) do
        if profile.humanSpawned == true then
            -- Persistencia ainda em validacao: NUNCA criar um clone ao carregar.
            count = count + 1
            local old = Adapter.get(profile.id)
            if old then Controller.attach(profile, old) end
        else
            local ok, actor, err = pcall(Adapter.spawn, player, profile, reserved)
            if ok and actor then
                profile.humanSpawned = true
                count = count + 1
                Controller.attach(profile, actor)
                Core.log("NPC humano confirmado: " .. profile.id ..
                    " | nome=" .. profile.firstName)
            else
                local why = ok and err or actor
                failures[#failures + 1] = index .. ": " .. tostring(why)
                Core.log("Falha NPC " .. index .. ": " .. tostring(why))
            end
        end
    end
    Adapter.restoreOwner(player)
    data.spawnedCount = count
    data.spawnAttempted = true
    if count == data.roster.count then
        data.spawnStatus = "human_spawned"
        Core.log("HUMAN SPAWN: " .. count .. "/" .. data.roster.count ..
            " NPCs IsoPlayer criados (renderizacao aguardando validacao in-game)")
    elseif data.spawnAttempts >= Boot.maxRetries then
        data.spawnStatus = "blocked_human"
        Core.log("HUMAN SPAWN parcial/bloqueado: " .. count ..
            "/" .. data.roster.count .. " | " .. table.concat(failures, "; "))
    else
        data.spawnStatus = "retry_human"
        Core.log("HUMAN SPAWN tentativa " .. data.spawnAttempts ..
            " : " .. count .. "/" .. data.roster.count)
    end
end

local function onNewGame(player)
    if Core.isSolo() then storeNewRoster(player) end
end

local function onTick()
    if not Core.isSolo() then return end
    Boot.ticks = Boot.ticks + 1
    local player = currentPlayer()
    -- O controlador internamente limita seus ticks a 45, sem trabalho por frame.
    if player then Controller.update(player) end
    if Boot.ticks % Boot.interval ~= 0 then return end
    if not player or not player.getModData then return end
    -- World map is player-owned and shared by this solo NPC team.
    MapKnowledge.update(player)
    if Core.pendingRoster then storeNewRoster(player) end
    local data = player:getModData().SupraNPC
    if not data then return end
    migrateDisabledRoster(data)
    if data.spawnStatus == "pending_human" or
       data.spawnStatus == "retry_human" then
        spawnStep(player, data)
    elseif data.spawnStatus == "human_spawned" then
        -- Reanexar objetos do mundo ao renderizador ao recarregar o save,
        -- sem criar clones em caso de entidades nao persistidas.
        local cell = getCell and getCell()
        for _, profile in ipairs(data.roster.profiles or {}) do
            if profile.humanSpawned and not Adapter.get(profile.id) then
                local existing = Adapter.findExisting(cell, profile.id)
                if existing then
                    Adapter.attach(profile.id, existing)
                    Controller.attach(profile, existing)
                    Core.log("NPC reanexado ao render: " .. profile.id)
                end
            end
        end
        if Boot.lastNotice ~= data.spawnStatus then
            Core.log("Equipe: human_spawned; restore de entidade apos reload ainda experimental")
            Boot.lastNotice = data.spawnStatus
        end
    elseif data.spawnStatus ~= Boot.lastNotice then
        Core.log("Equipe: estado=" .. tostring(data.spawnStatus) ..
            " gerados=" .. tostring(data.spawnedCount or 0))
        Boot.lastNotice = data.spawnStatus
    end
    Renderer.maintain(player)
    NPCUI.ensure(data.roster)
end

local function onPlayerUpdate(actor)
    -- Quando o callback vier do IsoPlayer adicional, garantir que a instancia
    -- global continue sendo o personagem controlado pelo usuario.
    if not Core.isSolo() or not actor then return end
    for _, tracked in pairs(Adapter.actors) do
        if tracked == actor then
            Adapter.restoreOwner(currentPlayer())
            return
        end
    end
end

local function onGameBoot()
    Core.log("Versao " .. Core.VERSION .. " carregada; alvo B42.13.1")
    Core.log("Engine=" .. Adapter.MODE ..
        " | spawn experimental=" .. tostring(Core.EXPERIMENTAL_SPAWN))
    TeamSetup.install()
    TeamFlow.install()
    TeamFlow.bindButtons()
end

local function onGameStart()
    if not Core.isSolo() then return end
    Boot.ticks, Boot.lastNotice = 0, nil
    Adapter.clear()
    Renderer.reset()
    Controller.clear()
    NPCUI.close()
    MapKnowledge.reset()
    local player = currentPlayer()
    if player and player.getModData then
        if Core.pendingRoster then storeNewRoster(player) end
        local data = player:getModData().SupraNPC
        Core.log("OnGameStart: " .. (data and tostring(data.spawnStatus) or
            "sem equipe no primeiro callback; aguardar OnTick"))
    end
end

if Events then
    if Events.OnGameBoot then Events.OnGameBoot.Add(onGameBoot) end
    if Events.OnMainMenuEnter then Events.OnMainMenuEnter.Add(function()
        Core.prompted = false
        Core.pendingRoster = nil
        TeamSetup.openWindow = nil
        Adapter.clear()
        Renderer.reset()
        Controller.clear()
        NPCUI.close()
        MapKnowledge.reset()
        TeamSetup.install()
        TeamFlow.install()
        TeamFlow.bindButtons()
    end) end
    if Events.OnNewGame then Events.OnNewGame.Add(onNewGame) end
    if Events.OnGameStart then Events.OnGameStart.Add(onGameStart) end
    if Events.OnTick then Events.OnTick.Add(onTick) end
    if Events.OnPlayerUpdate then Events.OnPlayerUpdate.Add(onPlayerUpdate) end
end

Core.Boot = Boot
return Boot
