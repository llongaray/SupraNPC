package.path = "42/media/lua/client/?.lua;42/media/lua/shared/?.lua;" .. package.path
local Wardrobe = require("SupraNPC/Wardrobe")
local function color()
    return {getRedFloat=function() return 0.3 end,
        getGreenFloat=function() return 0.6 end,
        getBlueFloat=function() return 0.8 end}
end
local visual = {
    getHue=function() return 0.1 end,
    getBaseTexture=function() return 2 end,
    getTextureChoice=function() return 4 end,
    getTint=color
}
local original = {
    getFullType=function() return "Base.Shirt_FormalWhite" end,
    getVisual=function() return visual end
}
local desc = {
    getWornItems=function()
        return {size=function() return 1 end,
            get=function() return {getItem=function() return original end} end}
    end
}
local entries=Wardrobe.capture(desc)
assert(#entries==1 and entries[1].visual)
assert(entries[1].visual.hue==0.1 and entries[1].visual.baseTexture==2)
assert(entries[1].visual.textureChoice==4 and entries[1].visual.tint.g==0.6)
assert(Wardrobe.validate(entries))
assert(not Wardrobe.validate({{type="Base.Shirt",visual={hue=0/0}}}))
assert(not Wardrobe.validate({{type="Base.Shirt",visual={tint={r=4,g=0,b=0}}}}))

local applied, created = {}, nil
ImmutableColor = {new=function(r,g,b) return {r=r,g=g,b=b} end}
InventoryItemFactory = {CreateItem=function()
    local v = {
        setHue=function(self,n) applied.hue=n end,
        setBaseTexture=function(self,n) applied.base=n end,
        setTextureChoice=function(self,n) applied.texture=n end,
        setTint=function(self,c) applied.tint=c end
    }
    created = {getVisual=function() return v end,
        getBodyLocation=function() return "Torso" end}
    return created
end}
local inventory={AddItem=function() end}
local actor={getInventory=function() return inventory end,
    setWornItem=function() end,resetModelNextFrame=function() end}
local good,failed=Wardrobe.equip(actor,entries)
assert(good==1 and failed==0 and created)
assert(applied.hue==0.1 and applied.base==2 and applied.texture==4)
assert(applied.tint.r==0.3 and applied.tint.g==0.6 and applied.tint.b==0.8)
print("[SupraNPC] wardrobe_visual_spec: OK")

-- O fluxo correto do vanilla veste SurvivorDesc ANTES de IsoPlayer.new.
local dressed = {}
instanceItem = function(t)
    return {
        getBodyLocation=function() return "Torso" end,
        getVisual=function() return {
            setHue=function() end, setBaseTexture=function() end,
            setTextureChoice=function() end, setTint=function() end
        } end
    }
end
local descriptor = {
    setWornItem=function(_,loc,item)
        dressed[#dressed+1] = {loc=loc,item=item}
    end
}
local count, failures = Wardrobe.dressDescriptor(descriptor, entries)
assert(count == 1 and failures == 0 and #dressed == 1)
assert(dressed[1].loc == "Torso")

local already = {
    getWornItems=function()
        local list={size=function() return 1 end,
            get=function() return {getItem=function() return {
                getFullType=function() return "Base.Shirt_FormalWhite" end
            } end} end}
        return list
    end
}
local missing=Wardrobe.missing(already,entries)
assert(#missing == 0)
local required=Wardrobe.missing(already,{
    {type="Base.Shirt_FormalWhite"},
    {type="Base.Trousers_Denim"}
})
assert(#required == 1 and required[1].type == "Base.Trousers_Denim")
print("[SupraNPC] wardrobe descriptor e missing: OK")
