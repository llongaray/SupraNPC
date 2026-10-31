-- Fichas serializáveis e independentes dos NPCs, sem objetos Java.
local Core = require("SupraNPC/Constants")
local Roster = {}

local function newProfile(index)
    return {
        id = "supranpc_" .. tostring(index),
        firstName = "NPC",
        lastName = tostring(index),
        female = false,
        profession = "unemployed",
        traits = {},
        skills = {},
        appearance = {},
        status = { health = 100 },
        order = "FOLLOW",
        complete = false
    }
end

function Roster.new(count)
    local result = { schema = 1, count = Core.clampCount(count), profiles = {} }
    for index = 1, result.count do
        result.profiles[index] = newProfile(index)
    end
    return result
end

-- requireComplete é usado antes de iniciar uma nova partida, não no seletor.
function Roster.validate(data, requireComplete)
    if type(data) ~= "table" then return false, "equipe invalida" end
    local n = Core.clampCount(data.count)
    if n ~= data.count then return false, "quantidade fora do limite" end
    if type(data.profiles) ~= "table" then return false, "fichas ausentes" end
    local ids = {}
    for i = 1, n do
        local profile = data.profiles[i]
        if type(profile) ~= "table" then return false, "ficha NPC " .. i .. " ausente" end
        if type(profile.id) ~= "string" or profile.id == "" or ids[profile.id] then
            return false, "identificador ausente ou duplicado no NPC " .. i
        end
        ids[profile.id] = true
        if type(profile.firstName) ~= "string" or not profile.firstName:match("%S") then
            return false, "nome invalido para NPC " .. i
        end
        if type(profile.lastName) ~= "string" or not profile.lastName:match("%S") then
            return false, "sobrenome invalido para NPC " .. i
        end
        if type(profile.skills) ~= "table" or type(profile.traits) ~= "table" then
            return false, "habilidades/traits invalidas no NPC " .. i
        end
        for skill, level in pairs(profile.skills) do
            if type(skill) ~= "string" or type(level) ~= "number" or
                level ~= level or level < 0 or level > 10 or level % 1 ~= 0 then
                return false, "nivel de habilidade invalido no NPC " .. i
            end
        end
        for _, trait in pairs(profile.traits) do
            if type(trait) ~= "string" or trait == "" then
                return false, "trait invalido no NPC " .. i
            end
        end
        if type(profile.appearance) ~= "table" or type(profile.status) ~= "table" then
            return false, "aparencia/status invalidos no NPC " .. i
        end
        if requireComplete and profile.complete ~= true then
            return false, "NPC " .. i .. " ainda nao foi personalizado"
        end
    end
    return true
end

function Roster.copy(data)
    if type(data) ~= "table" then return nil end
    local function clone(value)
        if type(value) ~= "table" then return value end
        local target = {}
        for k, v in pairs(value) do target[k] = clone(v) end
        return target
    end
    return clone(data)
end

Core.Roster = Roster
return Roster
