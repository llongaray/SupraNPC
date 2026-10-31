-- Ponto de entrada do SupraNPC: inicialização, nova partida e atualização.
local Core = require("SupraNPC/Constants")
local Roster = require("SupraNPC/Roster")
local TeamSetup = require("SupraNPC/TeamSetup")
local TeamFlow = require("SupraNPC/TeamFlow")
local Adapter = require("SupraNPC/SpawnAdapter")
local Follow = require("SupraNPC/Follow")

local function onNewGame(player, square)
    if not Core.isSolo() or not player or not Core.pendingRoster then return end
    local valid, reason = Roster.validate(Core.pendingRoster)
    if not valid then
        Core.log("Equipe invalida: " .. tostring(reason))
        return
    end
    local modData = player:getModData()
    -- Fichas não contêm referências Java e podem ser salvas com o personagem.
    modData.SupraNPC = {
        schema = 1,
        roster = Roster.copy(Core.pendingRoster),
        spawnAttempted = false,
        spawnStatus = "awaiting_validation"
    }
    Core.log("Nova partida: " .. tostring(Core.pendingRoster.count) .. " companheiros planejados.")
    Core.pendingRoster = nil
end

local function onGameStart()
    if not Core.isSolo() then return end
    local player = getSpecificPlayer and getSpecificPlayer(0) or nil
    if not player or not player.getModData then return end
    local data = player:getModData().SupraNPC
    if not data or not data.roster then return end
    if data.roster.count == 0 then
        data.spawnStatus = "no_companions"
        return
    end
    if not Core.EXPERIMENTAL_SPAWN then
        Core.log("Equipe registrada, mas spawn experimental desligado: veja README.")
        return
    end
    if data.spawnAttempted then
        Core.log("Spawn ja tentado nesta partida; evitando NPCs duplicados.")
        return
    end

    -- Marcar antes de criar entidades para impedir duplicação por reentrada.
    data.spawnAttempted = true
    local reserved = {}
    local spawned, failures = 0, {}
    for index = 1, data.roster.count do
        local profile = data.roster.profiles[index]
        local npc, err = Adapter.spawn(player, profile, reserved)
        if npc then
            spawned = spawned + 1
            Follow.register(profile.id, npc)
        else
            failures[#failures + 1] = tostring(index) .. ": " .. tostring(err)
        end
    end
    data.spawnStatus = #failures == 0 and "experiment_spawned" or "experiment_failed"
    data.spawnedCount = spawned
    for i = 1, #failures do Core.log("NPC " .. failures[i]) end
    Core.log("Tentativa experimental: " .. spawned .. "/" .. data.roster.count .. " NPC(s).")
end

local function onPlayerUpdate(player)
    -- Nada é alterado no personagem real. Roda a cada N ticks.
    if not Core.isSolo() or not player then return end
    local primary = getSpecificPlayer and getSpecificPlayer(0) or nil
    if primary and player == primary then Follow.update(player) end
end

local function onGameBoot()
    Core.log("Versao " .. Core.VERSION .. " carregada; alvo B42.13.1.")
    TeamSetup.install()
    TeamFlow.install()
end

if Events then
    if Events.OnGameBoot then Events.OnGameBoot.Add(onGameBoot) end
    -- Algumas builds inicializam os painéis do menu depois de OnGameBoot.
    if Events.OnMainMenuEnter then Events.OnMainMenuEnter.Add(function()
        TeamSetup.install()
        TeamFlow.install()
    end) end
    if Events.OnNewGame then Events.OnNewGame.Add(onNewGame) end
    if Events.OnGameStart then Events.OnGameStart.Add(onGameStart) end
    if Events.OnPlayerUpdate then Events.OnPlayerUpdate.Add(onPlayerUpdate) end
end
