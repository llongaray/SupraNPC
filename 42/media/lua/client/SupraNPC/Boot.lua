-- SupraNPC 0.1.4-dev: criacao de fichas; spawn inseguro desativado.
-- A tentativa 0.1.3 de proxy criou zumbis reais e foi bloqueada.
local Core = require("SupraNPC/Constants")
local Roster = require("SupraNPC/Roster")
local TeamSetup = require("SupraNPC/TeamSetup")
local TeamFlow = require("SupraNPC/TeamFlow")
local Adapter = require("SupraNPC/SpawnAdapter")

local Boot = { ticks = 0, lastNotice = nil, retryInterval = 90, maxRetries = 8 }

local function persistPending(player)
    if not player or not player.getModData or not Core.pendingRoster then return false end
    local valid, reason = Roster.validate(Core.pendingRoster, true)
    if not valid then
        Core.log("Equipe incompleta: " .. tostring(reason))
        return false
    end
    local modData = player:getModData()
    if modData.SupraNPC then
        Core.log("Equipe antiga no save mantida; nenhuma duplicacao de roster.")
        Core.pendingRoster = nil
        return false
    end
    local roster = Roster.copy(Core.pendingRoster)
    modData.SupraNPC = {
        schema = 2,
        roster = roster,
        spawnedCount = 0,
        spawnAttempts = 0,
        spawnStatus = Core.EXPERIMENTAL_SPAWN and "pending_proxy" or "disabled",
        spawnAttempted = false
    }
    Core.log("Nova partida: " .. tostring(roster.count) ..
        " NPC(s). Modo de spawn=" .. tostring(modData.SupraNPC.spawnStatus))
    for index, profile in ipairs(roster.profiles) do
        Core.log("Ficha " .. index .. ": " .. tostring(profile.firstName) .. " " ..
            tostring(profile.lastName) .. " (profissao " .. tostring(profile.profession) .. ")")
    end
    Core.pendingRoster = nil
    return true
end

local function onNewGame(player, square)
    if Core.isSolo() then persistPending(player) end
end

local function currentPlayer()
    return getSpecificPlayer and getSpecificPlayer(0) or nil
end

local function spawnStep(player, data)
    if Adapter.MODE == "disabled" then
        if data then data.spawnStatus = "blocked_unsafe_proxy" end
        Core.log("SPAWN BLOQUEADO: criacao de zumbis nao equivale a NPC humano.")
        return
    end
    if not Core.EXPERIMENTAL_SPAWN then return end
    if not data or not data.roster or
        (data.spawnStatus ~= "pending_proxy" and data.spawnStatus ~= "retry_proxy") then
        return
    end
    if data.roster.count == 0 then
        data.spawnStatus = "no_companions"
        return
    end
    if data.spawnAttempts >= Boot.maxRetries then
        data.spawnStatus = "blocked"
        Core.log("Spawn bloqueado apos " .. Boot.maxRetries ..
            " tentativas. Envie console.txt antes de tentar outra vez.")
        return
    end

    data.spawnAttempts = data.spawnAttempts + 1
    local reserved = {}
    local count, pending = 0, {}
    for index = 1, data.roster.count do
        local profile = data.roster.profiles[index]
        if profile.proxySpawned then
            count = count + 1
        else
            local ok, actor, reason = pcall(Adapter.spawn, player, profile, reserved)
            if ok and actor then
                profile.proxySpawned = true
                count = count + 1
                -- Este ator NAO e registrado no Follow: ainda e IsoZombie,
                -- e nao deve correr em direcao ao jogador/arriscar ataques.
            else
                local errorText = ok and reason or actor
                pending[#pending + 1] = tostring(index) .. ":" .. tostring(errorText)
            end
        end
    end

    data.spawnedCount = count
    data.spawnAttempted = true
    if count == data.roster.count then
        data.spawnStatus = "proxy_spawned"
        Core.log("Spawn PROXY concluido " .. count .. "/" .. data.roster.count ..
            " (nao e IsoPlayer; comportamento de NPC ainda nao ativo).")
    else
        data.spawnStatus = "retry_proxy"
        Core.log("Spawn proxy tentativa " .. data.spawnAttempts .. ": " ..
            count .. "/" .. data.roster.count .. " | " .. table.concat(pending, "; "))
    end
end

local function onTick()
    if not Core.isSolo() then return end
    Boot.ticks = Boot.ticks + 1
    if Boot.ticks % Boot.retryInterval ~= 0 then return end
    local player = currentPlayer()
    if not player or not player.getModData then return end
    if Core.pendingRoster then persistPending(player) end
    local data = player:getModData().SupraNPC
    if not data then
        if Boot.lastNotice ~= "missing" then
            Core.log("Nenhuma equipe no save. Em nova partida confira o log de OnNewGame.")
            Boot.lastNotice = "missing"
        end
        return
    end
    if data.spawnStatus == "pending_proxy" or data.spawnStatus == "retry_proxy" then
        spawnStep(player, data)
    elseif Boot.lastNotice ~= data.spawnStatus then
        Core.log("Equipe no save: " .. tostring(data.roster and data.roster.count or 0) ..
            " | estado=" .. tostring(data.spawnStatus) ..
            " | gerados=" .. tostring(data.spawnedCount or 0))
        Boot.lastNotice = data.spawnStatus
    end
end

local function onZombieUpdate(zombie)
    -- Mitigacao para proxies antigos, mesmo com spawn novo desativado.
    if not zombie then return end
    local ok, data = pcall(function() return zombie:getModData() end)
    if ok and data and data.SupraNPC_Proxy == true then
        Adapter.enforceNeutral(zombie)
    end
end

local function onGameBoot()
    Core.log("Versao " .. Core.VERSION .. " carregada; jogo alvo B42.13.1.")
    Core.log("Spawn humano ainda NAO implementado. Modo=" .. tostring(Adapter.MODE) ..
        "; bloqueio de zumbis ativo.")
    TeamSetup.install()
    TeamFlow.install()
    TeamFlow.bindButtons()
end

local function onGameStart()
    if not Core.isSolo() then return end
    Boot.ticks = 0
    Boot.lastNotice = nil
    local player = currentPlayer()
    if player and player.getModData then
        if Core.pendingRoster then persistPending(player) end
        local data = player:getModData().SupraNPC
        Core.log("OnGameStart: " .. (data and tostring(data.spawnStatus) or
            "sem roster no primeiro callback; verificarei OnTick"))
    end
end

if Events then
    if Events.OnGameBoot then Events.OnGameBoot.Add(onGameBoot) end
    if Events.OnMainMenuEnter then Events.OnMainMenuEnter.Add(function()
        Core.prompted = false
        Core.pendingRoster = nil
        TeamSetup.openWindow = nil
        TeamSetup.install()
        TeamFlow.install()
        TeamFlow.bindButtons()
    end) end
    if Events.OnNewGame then Events.OnNewGame.Add(onNewGame) end
    if Events.OnGameStart then Events.OnGameStart.Add(onGameStart) end
    if Events.OnTick then Events.OnTick.Add(onTick) end
    if Events.OnZombieUpdate then Events.OnZombieUpdate.Add(onZombieUpdate) end
end

Core.Boot = Boot
return Boot
