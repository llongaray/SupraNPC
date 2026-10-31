-- Adaptador isolado: NÃO ativado por padrão até teste real na 42.13.1.
-- Falhas nunca devem interromper a criação do personagem do jogador.
local Core = require("SupraNPC/Constants")
local Adapter = {}

local OFFSETS = {
    { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 },
    { 1, 1 }, { -1, 1 }, { 1, -1 }, { -1, -1 },
    { 2, 0 }, { -2, 0 }, { 0, 2 }, { 0, -2 }
}

local function availableSquare(player, offset, reserved)
    local cell = getCell()
    local x = math.floor(player:getX()) + offset[1]
    local y = math.floor(player:getY()) + offset[2]
    local z = math.floor(player:getZ())
    local key = tostring(x) .. "," .. tostring(y) .. "," .. tostring(z)
    if reserved[key] then return nil end
    local square = cell and cell:getGridSquare(x, y, z)
    if not square then return nil end
    if square.isFree and not square:isFree(false) then return nil end
    if square.isSolid and square:isSolid() then return nil end
    reserved[key] = true
    return square
end

function Adapter.spawn(player, profile, reserved)
    if not Core.EXPERIMENTAL_SPAWN then
        return nil, "spawn experimental desativado ate validacao na B42.13.1"
    end
    if not player or not profile then return nil, "jogador ou ficha ausente" end
    if not SurvivorFactory or not IsoPlayer or not IsoPlayer.new then
        return nil, "API de criacao de sobrevivente indisponivel"
    end

    local location
    for i = 1, #OFFSETS do
        location = availableSquare(player, OFFSETS[i], reserved)
        if location then break end
    end
    if not location then return nil, "nenhum tile proximo seguro carregado" end

    local ok, npcOrErr = pcall(function()
        local descriptor = SurvivorFactory.CreateSurvivor()
        if not descriptor then error("SurvivorFactory nao retornou descriptor") end
        if descriptor.setForename then descriptor:setForename(profile.firstName) end
        if descriptor.setSurname then descriptor:setSurname(profile.lastName) end
        if descriptor.setFemale then descriptor:setFemale(profile.female or false) end

        local actor = IsoPlayer.new(
            getCell(), descriptor,
            location:getX(), location:getY(), location:getZ()
        )
        if not actor then error("IsoPlayer.new nao retornou personagem") end
        if actor.setNpc then actor:setNpc(true) end
        if actor.addToSquare then actor:addToSquare(location) end
        if actor.addToWorld then actor:addToWorld() end
        if actor.getModData then actor:getModData().SupraNPC_ID = profile.id end
        return actor
    end)
    if not ok then return nil, tostring(npcOrErr) end
    return npcOrErr, nil
end

Core.SpawnAdapter = Adapter
return Adapter
