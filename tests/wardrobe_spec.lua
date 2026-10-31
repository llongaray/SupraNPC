-- Wardrobe nao depende de runtime do PZ para testar snapshots e equip.
package.path = "42/media/lua/client/?.lua;42/media/lua/shared/?.lua;" .. package.path
local Wardrobe = require("SupraNPC/Wardrobe")
local function item(t, loc)
    return {
        getFullType = function() return t end,
        getBodyLocation = function() return loc or "Torso" end
    }
end

local worn = {
    entries = {
        { getItem = function() return item("Base.Shirt_FormalWhite", "Torso") end },
        { getItem = function() return item("Base.Trousers_Denim", "Pants") end },
        { getItem = function() return item("Base.Shoes_Black", "Shoes") end }
    },
    size = function(self) return #self.entries end,
    get = function(self,index) return self.entries[index + 1] end
}
local desc = { getWornItems = function() return worn end }
local saved = Wardrobe.capture(desc)
assert(#saved == 3)
assert(saved[1].type == "Base.Shirt_FormalWhite")
assert(saved[2].type == "Base.Trousers_Denim")
assert(saved[3].type == "Base.Shoes_Black")
assert(Wardrobe.validate(saved))
assert(not Wardrobe.validate({{type="definitely invalid;lua()"}}))
assert(not Wardrobe.validate({{type=5}}))
assert(not Wardrobe.validate(nil))
assert(#Wardrobe.capture({}) == 0)

local created, wornItems = {}, {}
InventoryItemFactory = {
    CreateItem = function(t)
        created[#created + 1] = t
        return item(t, "Torso")
    end
}
local inventory = {
    AddItem = function(self,i)
        self[#self+1] = i
        -- metodo vanilla pode ser void (nil) mesmo em caso de sucesso.
        return nil
    end
}
local actor = {
    getInventory = function() return inventory end,
    setWornItem = function(_,loc,i)
        assert(loc == "Torso")
        wornItems[#wornItems+1] = i
    end,
    resetModelNextFrame = function() end
}
local ok, fail = Wardrobe.equip(actor, saved)
assert(ok == 3 and fail == 0)
assert(#created == 3 and #wornItems == 3 and #inventory == 3)
local notOk = Wardrobe.equip(actor, {{type="../bad"}})
assert(notOk == 0 and #created == 3)
local invalidActor, invalidFails = Wardrobe.equip(nil, saved)
assert(invalidActor == 0 and invalidFails == 0)
print("[SupraNPC] wardrobe_spec: OK")
