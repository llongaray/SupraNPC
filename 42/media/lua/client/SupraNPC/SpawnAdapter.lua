-- SupraNPC 0.1.4-dev: BLOQUEIO de spawn inseguro na B42.13.1.
-- Teste em jogo comprovou: addZombiesInOutfit cria ZUMBIS, nao NPCs.
-- A neutralizacao setNoTeeth/setUseless NAO converte em humano real.
-- A criacao de personagens e fichas permanece funcional em TeamFlow/Roster.
-- Substituir por adaptador humano comprovado SOMENTE depois de teste.
local Core = require("SupraNPC/Constants")
local Adapter = {
    MODE = "disabled",
    REASON = "Spawn bloqueado: adaptador antigo criava zumbis, nao NPCs humanos."
}

function Adapter.spawn(player, profile, reserved)
    -- Nao usar nem IsoPlayer.new (nao validado) nem addZombiesInOutfit
    -- (confirmado incorreto para companheiros reais).
    Core.log(Adapter.REASON)
    return nil, Adapter.REASON
end

function Adapter.enforceNeutral(actor)
    -- Mitigacao somente para entidades antigas identificadas pelo Boot
    -- com md.SupraNPC_Proxy == true. Nao converte em NPC e nao garante seguranca.
    if not actor then return false end
    local function try(method, ...)
        local ok, fn = pcall(function() return actor[method] end)
        if ok and fn then pcall(fn, actor, ...) end
    end
    try("setTarget", nil)
    try("setNoTeeth", true)
    try("setUseless", true)
    try("setVariable", "NoLungeTarget", true)
    return true
end

Core.SpawnAdapter = Adapter
return Adapter
