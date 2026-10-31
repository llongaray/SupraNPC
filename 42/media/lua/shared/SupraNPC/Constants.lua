-- SupraNPC - núcleo compartilhado (Kahlua / Lua 5.1)
-- Nenhuma dependência externa; build de referência 42.13.1.
SupraNPC = SupraNPC or {}
local M = SupraNPC
M.VERSION = "0.1.1-dev"
M.MOD_ID = "SupraNPC"
M.MAX_COMPANIONS = 5
M.DEFAULT_FOLLOW_DISTANCE = 2.5
M.THINK_INTERVAL = 20
M.DEBUG = true

-- A instanciação de IsoPlayer como NPC não foi validada em 42.13.1.
-- Ativação deliberadamente experimental e opt-in para preservar saves.
M.EXPERIMENTAL_SPAWN = false

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
