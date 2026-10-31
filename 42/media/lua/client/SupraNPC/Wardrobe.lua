-- SupraNPC - captura e equipa roupas do editor, sem guardar objetos Java no save.
-- B42.13.1: SurvivorDesc:getWornItems() e WornItems:get(index).
-- API defensiva: falhas nao alteram nem removem itens do jogador original.
local Core = require("SupraNPC/Constants")
local Wardrobe = {}

local function call(obj, name, ...)
    if not obj then return nil end
    local args = {...}
    local ok, result = pcall(function()
        return obj[name](obj, unpack(args))
    end)
    return ok and result or nil
end

local function itemType(raw)
    return type(raw) == "string" and #raw > 2 and #raw < 160
        and raw:match("^[%w_%-]+%.[%w_%-]+$") ~= nil
end

-- snapshot: array de {type="Base.X"}. Evita strings de display traduzidas.
function Wardrobe.capture(desc)
    local items = {}
    local worn = call(desc, "getWornItems")
    local count = tonumber(call(worn, "size")) or 0
    if count < 0 or count > 80 then
        return items, "contagem de roupas fora de limite"
    end
    for i = 0, count - 1 do
        local slot = call(worn, "get", i)
        local item = call(slot, "getItem") or call(worn, "getItemByIndex", i)
        local fullType = call(item, "getFullType")
        if itemType(fullType) then
            items[#items + 1] = { type = fullType }
        end
    end
    return items
end

function Wardrobe.validate(saved)
    if type(saved) ~= "table" or #saved > 80 then return false end
    for _, record in ipairs(saved) do
        if type(record) ~= "table" or not itemType(record.type) then return false end
    end
    return true
end

-- Em B42, o retorno de getBodyLocation pode ser String ou ItemBodyLocation.
local function locationOf(item)
    local raw = call(item, "getBodyLocation")
    if raw == nil then return nil end
    if type(raw) ~= "string" then return raw end
    if raw == "" then return nil end
    if ItemBodyLocation and ItemBodyLocation.get and ResourceLocation
        and ResourceLocation.of then
        local ok, loc = pcall(function()
            return ItemBodyLocation.get(ResourceLocation.of(raw))
        end)
        if ok and loc then return loc end
    end
    return raw  -- compatibilidade com implementacoes de B41
end

function Wardrobe.equip(actor, saved)
    if not actor then return 0, 0, "NPC ausente" end
    if not Wardrobe.validate(saved) then return 0, 0, "roupas invalidas" end
    if not InventoryItemFactory or not InventoryItemFactory.CreateItem then
        return 0, #saved, "InventoryItemFactory indisponivel"
    end
    local inventory = call(actor, "getInventory")
    if not inventory then return 0, #saved, "inventario indisponivel" end
    local worn, failed = 0, 0
    for _, record in ipairs(saved) do
        local okCreate, item = pcall(InventoryItemFactory.CreateItem, record.type)
        if okCreate and item then
            local location = locationOf(item)
            if location then
                local okAdd = pcall(function() inventory:AddItem(item) end)
                if okAdd then
                    local okWear = pcall(function()
                        actor:setWornItem(location, item)
                    end)
                    if okWear then worn = worn + 1 else failed = failed + 1 end
                else
                    failed = failed + 1
                end
            else
                failed = failed + 1
            end
        else
            failed = failed + 1
        end
    end
    if worn > 0 then call(actor, "resetModelNextFrame") end
    return worn, failed
end

Core.Wardrobe = Wardrobe
return Wardrobe
