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

local function finite(v)
    return type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge
end

local function visualNumber(visual, method, low, high)
    local n = call(visual, method)
    if not finite(n) or n < low or n > high then return nil end
    return n
end

local function readTint(visual)
    local color = call(visual, "getTint")
    if not color then return nil end
    local r = call(color, "getRedFloat")
    local g = call(color, "getGreenFloat")
    local b = call(color, "getBlueFloat")
    if not finite(r) or not finite(g) or not finite(b) or
       r < 0 or r > 1 or g < 0 or g > 1 or b < 0 or b > 1 then
        return nil
    end
    return {r = r, g = g, b = b}
end

local function captureVisual(item)
    local visual = call(item, "getVisual")
    if not visual then return nil end
    local snapshot = {
        hue = visualNumber(visual, "getHue", -1, 1),
        baseTexture = visualNumber(visual, "getBaseTexture", -1, 1000),
        textureChoice = visualNumber(visual, "getTextureChoice", -1, 1000),
        tint = readTint(visual)
    }
    if snapshot.hue == nil and snapshot.baseTexture == nil and
       snapshot.textureChoice == nil and snapshot.tint == nil then
        return nil
    end
    return snapshot
end

local function validTint(t)
    return type(t) == "table" and finite(t.r) and finite(t.g) and finite(t.b)
        and t.r >= 0 and t.r <= 1 and t.g >= 0 and t.g <= 1
        and t.b >= 0 and t.b <= 1
end

local function validVisual(v)
    if type(v) ~= "table" then return false end
    if v.hue ~= nil and (not finite(v.hue) or v.hue < -1 or v.hue > 1) then return false end
    for _, key in ipairs({"baseTexture", "textureChoice"}) do
        local n = v[key]
        if n ~= nil and (not finite(n) or n < -1 or n > 1000 or n % 1 ~= 0) then return false end
    end
    if v.tint ~= nil and not validTint(v.tint) then return false end
    return true
end

local function applyVisual(item, saved)
    if type(saved) ~= "table" then return end
    local visual = call(item, "getVisual")
    if not visual then return end
    if saved.hue ~= nil then call(visual, "setHue", saved.hue) end
    if saved.baseTexture ~= nil then call(visual, "setBaseTexture", saved.baseTexture) end
    if saved.textureChoice ~= nil then call(visual, "setTextureChoice", saved.textureChoice) end
    if validTint(saved.tint) and ImmutableColor and ImmutableColor.new then
        local ok, color = pcall(ImmutableColor.new,
            saved.tint.r, saved.tint.g, saved.tint.b)
        if ok and color then call(visual, "setTint", color) end
    end
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
        local loc = call(slot, "getLocation")
        if loc ~= nil then loc = tostring(loc) end
        if itemType(fullType) then
            items[#items + 1] = {
                type = fullType, location = loc, visual = captureVisual(item)
            }
        end
    end
    return items
end

function Wardrobe.validate(saved)
    if type(saved) ~= "table" or #saved > 80 then return false end
    for _, record in ipairs(saved) do
        if type(record) ~= "table" or not itemType(record.type) or
           (record.visual ~= nil and not validVisual(record.visual)) or
           (record.location ~= nil and (type(record.location) ~= "string"
             or #record.location > 120 or not
             record.location:match("^[%w_:%-]+$"))) then return false end
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

-- O vanilla chama SurvivorDesc:setWornItem ANTES da criacao do player.
-- Isto evita depender da sincronizacao de IsoPlayer:setWornItem apos o spawn.
local function resolveLocation(raw)
    if not raw then return nil end
    if ItemBodyLocation and ItemBodyLocation.get and
       ResourceLocation and ResourceLocation.of then
        local ok, result = pcall(function()
            return ItemBodyLocation.get(ResourceLocation.of(tostring(raw)))
        end)
        if ok and result then return result end
    end
    return raw
end

function Wardrobe.dressDescriptor(desc, saved)
    if not desc or not Wardrobe.validate(saved) then
        return 0, "descriptor ou roupas invalidas"
    end
    if type(instanceItem) ~= "function" then
        return 0, "API instanceItem indisponivel"
    end
    local dressed, failed = 0, 0
    for _, record in ipairs(saved) do
        local ok, item = pcall(instanceItem,record.type)
        if ok and item then
            applyVisual(item,record.visual)
            local slot = resolveLocation(record.location) or locationOf(item)
            if slot then
                local good = pcall(function()
                    desc:setWornItem(slot,item)
                end)
                if good then dressed = dressed + 1 else failed = failed + 1 end
            else failed = failed + 1 end
        else failed = failed + 1 end
    end
    return dressed, failed
end

-- Só equipar peças que ainda não estão vestidas. Um IsoPlayer pode
-- herdar uma parte do outfit do descriptor, mas deixar outras de fora.
function Wardrobe.missing(actor, saved)
    if not Wardrobe.validate(saved) then return nil end
    local worn = call(actor, "getWornItems")
    local n = tonumber(call(worn,"size")) or 0
    local counts = {}
    for i=0,math.min(n,80)-1 do
        local slot = call(worn,"get",i)
        local item = call(slot,"getItem") or call(worn,"getItemByIndex",i)
        local full = call(item,"getFullType")
        if type(full)=="string" then
            counts[full] = (counts[full] or 0)+1
        end
    end
    local remaining={}
    for _, rec in ipairs(saved) do
        if (counts[rec.type] or 0)>0 then
            counts[rec.type]=counts[rec.type]-1
        else
            remaining[#remaining+1]=rec
        end
    end
    return remaining
end

function Wardrobe.equip(actor, saved)
    if not actor then return 0, 0, "NPC ausente" end
    if not Wardrobe.validate(saved) then return 0, 0, "roupas invalidas" end
    if not InventoryItemFactory or not InventoryItemFactory.CreateItem then
        return 0, #saved, "InventoryItemFactory indisponivel"
    end
    local inventory = call(actor, "getInventory")
    if not inventory then return 0, #saved, "inventario indisponivel" end
    local worn, failed, firstError = 0, 0, nil
    local function failure(itemName, reason)
        failed = failed + 1
        if not firstError then firstError = tostring(itemName) .. ": " .. tostring(reason) end
    end
    for _, record in ipairs(saved) do
        local okCreate, item = pcall(InventoryItemFactory.CreateItem, record.type)
        if okCreate and item then
            applyVisual(item, record.visual)
            local location = resolveLocation(record.location) or locationOf(item)
            if location then
                local okAdd, addError = pcall(function() inventory:AddItem(item) end)
                if okAdd then
                    local okWear, wearError = pcall(function()
                        actor:setWornItem(location, item)
                    end)
                    if okWear then
                        worn = worn + 1
                    else
                        failure(record.type, "setWornItem: " .. tostring(wearError))
                    end
                else
                    failure(record.type, "AddItem: " .. tostring(addError))
                end
            else
                failure(record.type, "bodyLocation indisponivel")
            end
        else
            failure(record.type, "CreateItem: " .. tostring(item))
        end
    end
    if worn > 0 then call(actor, "resetModelNextFrame") end
    return worn, failed, firstError
end

Core.Wardrobe = Wardrobe
return Wardrobe
