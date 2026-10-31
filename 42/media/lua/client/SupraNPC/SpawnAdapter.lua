-- SupraNPC 0.1.3-dev - adaptador de spawn B42 (single-player).
-- IsoPlayer.new nao e um mecanismo de NPC normal comprovado no B42.13.1.
-- Este prototipo usa uma entidade IsoZombie com roupa humana, neutralizada.
-- Trata-se de um CORPO PROVISORIO, nao de um IsoPlayer/NPC humano real.
local Core = require("SupraNPC/Constants")
local Adapter = { MODE = "proxy" }

local OFFSETS = {}
for radius = 1, 4 do
    for dx = -radius, radius do
        for dy = -radius, radius do
            if math.max(math.abs(dx), math.abs(dy)) == radius then
                OFFSETS[#OFFSETS + 1] = { dx, dy }
            end
        end
    end
end

local OUTFITS = {
    carpenter = "ConstructionWorker", constructionworker = "ConstructionWorker",
    firefighter = "Fireman", fireofficer = "Fireman",
    doctor = "Doctor", nurse = "Nurse",
    chef = "Chef", farmer = "Farmer",
    mechanic = "Mechanic", policeofficer = "Police", parkRanger = "Ranger",
    unemployed = "Survivalist"
}

local function call(object, method, ...)
    if not object then return false, nil end
    local okMethod, fn = pcall(function() return object[method] end)
    if not okMethod or not fn then return false, nil end
    local ok, value = pcall(fn, object, ...)
    return ok, value
end

local function safeSquare(square)
    if not square then return false end
    local freeOk, free = call(square, "isFree", false)
    if not freeOk or not free then return false end
    local solidOk, solid = call(square, "isSolid")
    if solidOk and solid then return false end
    return true
end

function Adapter.pickSquare(player, reserved)
    if not player or not getCell then return nil, nil end
    local cell = getCell()
    if not cell then return nil, nil end
    local x = math.floor(player:getX())
    local y = math.floor(player:getY())
    local z = math.floor(player:getZ())
    local origin = player:getSquare()
    local originRoom = origin and origin.getRoom and origin:getRoom() or nil

    -- Priorizar o mesmo ambiente; nao espalhar companheiros no lado oposto
    -- da parede quando o jogador inicia dentro de uma casa.
    for pass = 1, 2 do
        for _, offset in ipairs(OFFSETS) do
            local nx, ny = x + offset[1], y + offset[2]
            local key = tostring(nx) .. ":" .. tostring(ny) .. ":" .. tostring(z)
            if not reserved[key] then
                local square = cell:getGridSquare(nx, ny, z)
                if safeSquare(square) then
                    local room = square.getRoom and square:getRoom() or nil
                    if (pass == 1 and originRoom == room) or pass == 2 then
                        return square, key
                    end
                end
            end
        end
    end
    return nil, nil
end

function Adapter.enforceNeutral(actor)
    if not actor then return end
    -- Os proxies possuem chassi IsoZombie: impedir ataque em todo update.
    call(actor, "setTarget", nil)
    call(actor, "setNoTeeth", true)
    call(actor, "setUseless", true)
    call(actor, "setVariable", "NoLungeTarget", true)
end

function Adapter.quietProxy(actor, profile)
    if not actor then return false end
    Adapter.enforceNeutral(actor)
    call(actor, "setDressInRandomOutfit", false)
    call(actor, "setFemaleEtc", profile.female == true)
    call(actor, "setWalkType", "Walk")
    local mdOk, md = call(actor, "getModData")
    if not mdOk or not md then return false end
    md.SupraNPC_ID = profile.id
    md.SupraNPC_Name = tostring(profile.firstName) .. " " .. tostring(profile.lastName)
    md.SupraNPC_Proxy = true
    md.SupraNPC_Order = "HOLD"
    md.SupraNPC_Profession = profile.profession

    local visualOk, visual = call(actor, "getHumanVisual")
    if visualOk and visual and type(profile.appearance) == "table" then
        if profile.appearance.hair and profile.appearance.hair ~= "" then
            call(visual, "setHairModel", profile.appearance.hair)
        end
        if profile.appearance.beard and profile.appearance.beard ~= "" then
            call(visual, "setBeardModel", profile.appearance.beard)
        end
        if type(profile.appearance.skinIndex) == "number" then
            call(visual, "setSkinTextureIndex", profile.appearance.skinIndex)
        end
        call(actor, "resetModelNextFrame")
    end
    return true
end

function Adapter.spawn(player, profile, reserved)
    if not Core.EXPERIMENTAL_SPAWN then return nil, "spawn desativado" end
    if not Core.isSolo() then return nil, "somente single-player" end
    if not player or not profile then return nil, "jogador ou ficha ausente" end
    if type(addZombiesInOutfit) ~= "function" then
        return nil, "API global addZombiesInOutfit indisponivel"
    end
    reserved = reserved or {}
    local square, key = Adapter.pickSquare(player, reserved)
    if not square then return nil, "nenhum tile livre nas proximidades (4 tiles)" end

    local prefer = OUTFITS[tostring(profile.profession)] or "Survivalist"
    local outfits = { prefer, "Survivalist", "Generic01" }
    for _, outfit in ipairs(outfits) do
        local ok, list = pcall(addZombiesInOutfit,
            square:getX(), square:getY(), square:getZ(),
            1, outfit, profile.female and 100 or 0)
        if not ok then
            Core.log("addZombiesInOutfit(" .. outfit .. ") falhou: " .. tostring(list))
        elseif list then
            local sizeOk, size = call(list, "size")
            if sizeOk and size and size > 0 then
                local itemOk, actor = call(list, "get", 0)
                if itemOk and actor then
                    if Adapter.quietProxy(actor, profile) then
                        reserved[key] = true
                        Core.log("PROXY spawn: " .. tostring(profile.id) .. " em " ..
                            square:getX() .. "," .. square:getY() .. "," .. square:getZ() ..
                            " outfit=" .. outfit)
                        return actor, nil
                    end
                    return nil, "entidade criada sem ModData; inspecione console"
                end
            end
        end
    end
    return nil, "addZombiesInOutfit nao retornou entidade (ver populacao de zumbis)"
end

Core.SpawnAdapter = Adapter
return Adapter
