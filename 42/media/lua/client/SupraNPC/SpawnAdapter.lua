-- SupraNPC - B42.13.1: instancia IsoPlayer nativa baseada em ArayHumanNPCTest.
-- Somente jogo solo. NUNCA usa addZombiesInOutfit.
-- Este modulo trata de spawn e ownership, NAO da logica de IA.
local Core = require("SupraNPC/Constants")
local Wardrobe = require("SupraNPC/Wardrobe")
local Adapter = { MODE = "iso_player", actors = {}, attempt = 0 }

local OFFSETS = {
    {1,0},{-1,0},{0,1},{0,-1}, {1,1},{1,-1},{-1,1},{-1,-1},
    {2,0},{-2,0},{0,2},{0,-2}, {2,1},{2,-1},{-2,1},{-2,-1},
    {1,2},{-1,2},{1,-2},{-1,-2}, {3,0},{-3,0},{0,3},{0,-3}
}

local function call(obj, method, ...)
    if not obj then return nil end
    local args = {...}
    local ok, result = pcall(function()
        return obj[method](obj, unpack(args))
    end)
    if ok then return result end
    return nil
end

local function restoreOwner(player)
    if not player then return end
    if IsoPlayer and IsoPlayer.setInstance then
        pcall(function() IsoPlayer.setInstance(player) end)
    end
    if IsoCamera and IsoCamera.setCameraCharacter then
        pcall(function()
            IsoCamera.setCameraCharacter(player)
        end)
    end
end
Adapter.restoreOwner = restoreOwner

local function isFree(square, reserved, key)
    if not square or reserved[key] then return false end
    if not call(square, "TreatAsSolidFloor") then return false end
    if call(square, "isFree", false) ~= true then return false end
    local list = call(square, "getMovingObjects")
    if list then
        local size = call(list, "size") or 0
        for index = 0, size - 1 do
            local obj = call(list, "get", index)
            if obj and instanceof and instanceof(obj, "IsoGameCharacter") then
                return false
            end
        end
    end
    return true
end

function Adapter.pickSquare(player, cell, reserved)
    if not player or not cell then return nil, nil end
    reserved = reserved or {}
    local px, py, pz = math.floor(player:getX()),
        math.floor(player:getY()), math.floor(player:getZ())
    local own = call(player, "getSquare")
    local ownRoom = call(own, "getRoom")
    for pass = 1, 2 do
        for _, offset in ipairs(OFFSETS) do
            local x, y = px + offset[1], py + offset[2]
            local key = x .. ":" .. y .. ":" .. pz
            local sq = call(cell, "getGridSquare", x, y, pz)
            if isFree(sq, reserved, key) then
                local room = call(sq, "getRoom")
                if (pass == 1 and room == ownRoom) or pass == 2 then
                    return sq, key
                end
            end
        end
    end
    return nil, nil
end

local function findExisting(cell, id)
    if not cell or not id then return nil end
    local objects = call(cell, "getObjectList")
    local count = call(objects, "size") or 0
    for i = 0, count - 1 do
        local obj = call(objects, "get", i)
        if obj and obj.getModData then
            local md = call(obj, "getModData")
            if md and md.SupraNPC_IsNPC == true and md.SupraNPC_ID == id and
               (not instanceof or instanceof(obj, "IsoPlayer")) then
                return obj
            end
        end
    end
    return nil
end
Adapter.findExisting = findExisting

function Adapter.get(id)
    return Adapter.actors[id]
end

function Adapter.attach(id, actor)
    if not id or not actor then return false end
    Adapter.actors[id] = actor
    return true
end

function Adapter.clear()
    Adapter.actors = {}
    Adapter.attempt = 0
end

local function descriptorFor(profile)
    local desc = nil
    if SurvivorFactory and SurvivorFactory.CreateSurvivor then
        desc = SurvivorFactory.CreateSurvivor()
    end
    if not desc and SurvivorDesc and SurvivorDesc.new then
        desc = SurvivorDesc.new()
    end
    if not desc then return nil end
    desc:setForename(profile.firstName)
    desc:setSurname(profile.lastName)
    if desc.setFemale then desc:setFemale(profile.female == true) end
    local visual = call(desc, "getHumanVisual")
    local app = profile.appearance or {}
    if visual then
        if type(app.hair) == "string" and app.hair ~= "" then
            call(visual, "setHairModel", app.hair)
        end
        if type(app.beard) == "string" and app.beard ~= "" then
            call(visual, "setBeardModel", app.beard)
        end
        if type(app.skinIndex) == "number" then
            call(visual, "setSkinTextureIndex", app.skinIndex)
        end
    end
    -- O editor original usa SurvivorDesc.setWornItem, antes de IsoPlayer.new.
    -- A tentativa anterior apenas equipava itens apos construir o NPC,
    -- quando o modelo nem sempre re-sincroniza os visuais.
    local outfit = app.clothing
    if Wardrobe.validate(outfit) and #outfit > 0 then
        local count, failed = Wardrobe.dressDescriptor(desc, outfit)
        Core.log("NPC " .. profile.id .. ": roupas no descriptor=" ..
            tostring(count) .. "/" .. tostring(#outfit) ..
            " falhas=" .. tostring(failed))
    end
    return desc
end

-- Somente fallback quando o editor nao forneceu roupa alguma.
local BASIC_CLOTHES = {
    {type = "Base.Tshirt_DefaultTEXTURE"},
    {type = "Base.Trousers_DefaultTEXTURE"},
    {type = "Base.Shoes_Black"}
}

local function dressFromProfile(actor, profile)
    local outfit = profile.appearance and profile.appearance.clothing
    if not Wardrobe.validate(outfit) or #outfit == 0 then
        Core.log("NPC " .. profile.id .. ": sem roupas registradas, tentando kit basico")
        outfit = BASIC_CLOTHES
    end
    local missing = Wardrobe.missing(actor, outfit)
    if not missing then
        Core.log("NPC " .. profile.id .. ": snapshot de roupas invalido")
        return
    end
    Core.log("NPC " .. profile.id .. ": pecas desejadas=" ..
        tostring(#outfit) .. " faltando=" .. tostring(#missing))
    if #missing == 0 then return end
    local worn, failed, reason = Wardrobe.equip(actor, missing)
    Core.log("NPC " .. profile.id .. ": vestidos=" .. tostring(worn) ..
        "/" .. tostring(#missing) .. " falhas=" .. tostring(failed) ..
        (reason and (" motivo=" .. tostring(reason)) or ""))
    -- O NPC deve continuar existindo mesmo se uma peca for incompatível.
end

local function place(actor, square)
    local x, y, z = square:getX() + 0.5, square:getY() + 0.5, square:getZ()
    call(actor, "removeFromSquare")
    call(actor, "teleportTo", x, y, z)
    for _, entry in ipairs({
        {"setX",x}, {"setY",y}, {"setZ",z},
        {"setLastX",x}, {"setLastY",y},
        {"setNextX",x}, {"setNextY",y},
        {"setScriptNextX",x}, {"setScriptNextY",y}
    }) do call(actor, entry[1], entry[2]) end
    call(actor, "setCurrentSquareFromPosition")
    local current = call(actor, "getCurrentSquare") or square
    call(actor, "setCurrent", current)
    local movers = call(current, "getMovingObjects")
    if movers and call(movers, "contains", actor) ~= true then
        call(movers, "add", actor)
    end
    call(actor, "setSceneCulled", false)
    call(actor, "setAlpha", 1)
    call(actor, "setTargetAlpha", 1)
end

local function dispose(actor)
    if not actor then return end
    call(actor, "removeFromWorld")
    call(actor, "removeFromSquare")
end

function Adapter.spawn(player, profile, reserved)
    if not Core.EXPERIMENTAL_SPAWN or Adapter.MODE ~= "iso_player" then
        return nil, "spawn humano desativado"
    end
    if not Core.isSolo() then return nil, "somente single-player" end
    if not player or not profile or type(profile.id) ~= "string" then
        return nil, "jogador/ficha invalido"
    end
    if not IsoPlayer or not IsoPlayer.new or not getCell then
        return nil, "API IsoPlayer.new/getCell ausente"
    end
    local cell = getCell()
    if not cell then return nil, "cell indisponivel" end
    local existing = Adapter.actors[profile.id] or findExisting(cell, profile.id)
    if existing then
        Adapter.attach(profile.id, existing)
        restoreOwner(player)
        return existing, nil, true
    end
    local square, key = Adapter.pickSquare(player, cell, reserved)
    if not square then return nil, "sem tile livre proximo ao jogador" end

    -- Criar o objeto nativo uma vez. IsoPlayer.new pode alterar o jogador global.
    local actor
    local ok, err = pcall(function()
        local desc = assert(descriptorFor(profile), "sem SurvivorDesc")
        actor = assert(IsoPlayer.new(cell, desc,
            square:getX(), square:getY(), square:getZ()), "IsoPlayer.new nil")
        assert(call(actor, "getBodyDamage"), "IsoPlayer sem BodyDamage")
        call(actor, "setNPC", true)
        local md = assert(call(actor, "getModData"), "NPC sem ModData")
        md.SupraNPC_IsNPC = true
        md.SupraNPC_ID = profile.id
        md.SupraNPC_Name = profile.firstName .. " " .. profile.lastName
        md.SupraNPC_Profession = profile.profession
        md.SupraNPC_Order = profile.order or "FOLLOW"
        md.SupraNPC_Engine = "IsoPlayer"
        dressFromProfile(actor, profile)
        place(actor, square)
        call(actor, "resetModelNextFrame")
    end)
    -- Restaurar SEMPRE, inclusive se a inicializacao do personagem falhar.
    restoreOwner(player)
    if not ok then
        dispose(actor)
        Core.log("Falha de IsoPlayer " .. tostring(profile.id) .. ": " .. tostring(err))
        return nil, tostring(err)
    end
    reserved[key] = true
    Adapter.attach(profile.id, actor)
    Core.log("HUMAN spawn " .. profile.id .. " " .. profile.firstName ..
        " x=" .. tostring(square:getX()) .. " y=" .. tostring(square:getY()) ..
        " isNPC=" .. tostring(call(actor, "isNPC")))
    return actor, nil, false
end

Core.SpawnAdapter = Adapter
return Adapter
