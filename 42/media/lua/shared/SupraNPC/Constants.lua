-- SupraNPC - núcleo compartilhado (Kahlua / Lua 5.1)
-- Nenhuma dependência externa; build de referência 42.13.1.
SupraNPC = SupraNPC or {}
local M = SupraNPC
M.VERSION = "0.1.6-dev"
M.MOD_ID = "SupraNPC"
M.MAX_COMPANIONS = 5
M.DEFAULT_FOLLOW_DISTANCE = 2.5
M.THINK_INTERVAL = 20
M.DEBUG = true

-- DESATIVADO APOS TESTE EM JOGO: addZombiesInOutfit cria ZUMBIS reais.
-- Nao habilitar este adaptador para NPCs humanos. A neutralizacao falhou.
-- Manter as telas de criacao e fichas; nenhum spawn ate implementacao correta.
M.EXPERIMENTAL_SPAWN = false
M.NPC_BODY_MODE = "unimplemented"
M.PROXY_FOLLOW = false

function M.log(message)
    if M.DEBUG then
        print("[SupraNPC] " .. tostring(message))
    end
end

function M.clampCount(value)
    local n = tonumber(value) or 0
    n = math.floor(n)
    if n < 0 then return 0 end
    if n > M.MAX_COMPANIONS then return M.MAX_COMPANIONS end
    return n
end

function M.isSolo()
    if type(isClient) == "function" and isClient() then return false end
    if type(isServer) == "function" and isServer() then return false end
    return true
end

return M
