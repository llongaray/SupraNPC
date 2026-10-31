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
        order = "FOLLOW"
    }
end

function Roster.new(count)
    local result = { schema = 1, count = Core.clampCount(count), profiles = {} }
    for index = 1, result.count do
        result.profiles[index] = newProfile(index)
    end
    return result
end

function Roster.validate(data)
    if type(data) ~= "table" then return false, "roster precisa ser tabela" end
    local n = Core.clampCount(data.count)
    if n ~= data.count then return false, "quantidade fora do limite" end
    if type(data.profiles) ~= "table" then return false, "profiles ausentes" end
    for i = 1, n do
        local profile = data.profiles[i]
        if type(profile) ~= "table" then return false, "perfil NPC " .. i .. " ausente" end
        if type(profile.id) ~= "string" or profile.id == "" then
            return false, "identificador invalido para NPC " .. i
        end
        if type(profile.firstName) ~= "string" or profile.firstName == "" then
            return false, "nome invalido para NPC " .. i
        end
        if type(profile.skills) ~= "table" or type(profile.traits) ~= "table" then
            return false, "habilidades/traits invalidas para NPC " .. i
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
