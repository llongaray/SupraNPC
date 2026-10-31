package.path="42/media/lua/client/?.lua;42/media/lua/shared/?.lua;"..package.path
local markers={
 {text="NPC:BASE:A",x=4,y=8},
 {text="NPC:BASE:B",x=11,y=14},
 {text="NPC:LOOT Pharmacy",x=20,y=5},
 {text="Nota qualquer",x=23,y=6},
 {text="ICON:skull",x=32,y=12,icon=true}
}
MapItem={getSingleton=function() return {
 getSymbols=function() return {
    getSymbolCount=function() return #markers end,
    getSymbolByIndex=function(_,i)
      local v=markers[i+1];return {
       isText=function() return not v.icon end,
       isTexture=function() return v.icon==true end,
       getSymbolID=function() return v.text:sub(6) end,
       getUntranslatedText=function() return v.icon and nil or v.text end,
       getWorldX=function() return v.x end,
       getWorldY=function() return v.y end}
    end}
 end} end}
local M=require("SupraNPC/NPCMapKnowledge")
local md={}
local player={getModData=function() return md end}
assert(M.update(player))
assert(M.get(player).base.defined=="RECT")
assert(#M.get(player).notes==5)
assert(require("SupraNPC/Territory").knowledge(M.get(player)).DANGER==1)
markers[1].text="NPC:PERIGO:A"
assert(M.update(player))
assert(M.get(player).base==nil)
M.reset()
MapItem=nil
assert(not M.update(player))
assert(M.get(player).base==nil)
print("[SupraNPC] map_knowledge_spec: OK")
