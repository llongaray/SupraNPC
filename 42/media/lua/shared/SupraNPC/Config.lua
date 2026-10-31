-- SupraNPC - opcoes puras, sem acesso ao jogo ou a arquivo.
-- Nenhuma opcao habilita spawn ou componentes experimentais.
local Core = require("SupraNPC/Constants")
local Config = {}

Config.RULES = {
    followDistance = {min = 1.0, max = 8.0, default = 2.5},
    guardRadius = {min = 1.0, max = 20.0, default = 5.0},
    protectRadius = {min = 2.0, max = 25.0, default = 8.0},
    thinkInterval = {min = 5, max = 120, default = 20, integer = true},
    stuckAfterTicks = {min = 30, max = 600, default = 150, integer = true},
    lowHealthThreshold = {min = 0.05, max = 0.70, default = 0.25},
    maxCompanions = {min = 0, max = Core.MAX_COMPANIONS, default = Core.MAX_COMPANIONS, integer = true},
    autoDefend = {kind = "boolean", default = true},
    protectPlayer = {kind = "boolean", default = true},
    debug = {kind = "boolean", default = false}
}

local function finite(value)
    return type(value) == "number" and value == value and
        value ~= math.huge and value ~= -math.huge
end

function Config.defaults()
    local out = {}
    for key, rule in pairs(Config.RULES) do out[key] = rule.default end
    return out
end

-- Retorna config completa + avisos. Valores malformados sao substituidos
-- por default, e valores fora do intervalo sao limitados ao intervalo.
function Config.sanitize(raw)
    local config, warnings = Config.defaults(), {}
    if raw == nil then return config, warnings end
    if type(raw) ~= "table" then
        warnings[#warnings + 1] = "config: esperado tabela"
        return config, warnings
    end
    for key, rule in pairs(Config.RULES) do
        local value = raw[key]
        if value ~= nil then
            if rule.kind == "boolean" then
                if type(value) == "boolean" then
                    config[key] = value
                else
                    warnings[#warnings + 1] = key .. ": esperado boolean"
                end
            elseif finite(value) then
                local clamped = math.max(rule.min, math.min(rule.max, value))
                if rule.integer then clamped = math.floor(clamped) end
                config[key] = clamped
                if clamped ~= value then
                    warnings[#warnings + 1] = key .. ": valor ajustado"
                end
            else
                warnings[#warnings + 1] = key .. ": numero invalido"
            end
        end
    end
    for key in pairs(raw) do
        if Config.RULES[key] == nil then
            warnings[#warnings + 1] = tostring(key) .. ": opcao desconhecida"
        end
    end
    table.sort(warnings)
    return config, warnings
end

function Config.validate(raw)
    if type(raw) ~= "table" then return false, "config invalida" end
    for key, value in pairs(raw) do
        local rule = Config.RULES[key]
        if not rule then return false, "opcao desconhecida: " .. tostring(key) end
        if rule.kind == "boolean" then
            if type(value) ~= "boolean" then return false, "boolean invalido: " .. key end
        else
            if not finite(value) or value < rule.min or value > rule.max or
               (rule.integer and value % 1 ~= 0) then
                return false, "numero invalido: " .. key
            end
        end
    end
    return true
end

-- Nunca define Core.EXPERIMENTAL_SPAWN ou altera estado do motor.
function Config.forSave(raw)
    local clean = Config.sanitize(raw)
    return {schema = 1, settings = clean}
end

Core.Config = Config
return Config
