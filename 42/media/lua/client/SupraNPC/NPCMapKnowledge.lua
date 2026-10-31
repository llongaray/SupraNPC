-- Read-only adapter for text annotations on the vanilla world map.
-- Does NOT alter the player's symbols, pencil, eraser or map UI.
local Core=require("SupraNPC/Constants")
local Territory=require("SupraNPC/Territory")
local M={current=Territory.new(),sourceAvailable=false}
local function call(o,key,...)
 if not o then return nil end
 local args={...};local ok,r=pcall(function()
   if o[key] then return o[key](o,unpack(args)) end end)
 if ok then return r end
end
local function symbols()
 -- A UIWorldMap API wrapper exposes getWorldX/getWorldY whereas raw
 -- MapItem WorldMapBaseSymbol objects may not have position getters.
 local frames={}
 if ISWorldMap and ISWorldMap.instance then
    frames[#frames+1]=ISWorldMap.instance
 end
 if ISWorldMap_instance then frames[#frames+1]=ISWorldMap_instance end
 for _,frame in ipairs(frames) do
    local candidates={frame,call(frame,"getAPI"),call(frame,"getMapAPI")}
    if frame.javaObject then
       candidates[#candidates+1]=frame.javaObject
       candidates[#candidates+1]=call(frame.javaObject,"getAPI")
    end
    for _,ui in ipairs(candidates) do
       local api=call(ui,"getSymbolsAPI")
       if api and call(api,"getSymbolCount")~=nil then
          return api
       end
    end
 end
 local m=nil
 if MapItem and MapItem.getSingleton then
   local ok,res=pcall(function() return MapItem.getSingleton() end)
   if ok then m=res end
 end
 if not m then return nil end
 local s=call(m,"getSymbols")
 if s and call(s,"getSymbolCount") then return s end
 -- Alternative B42 API wrappers, if provided by the game.
 s=call(m,"getSymbolsAPI")
 if s and call(s,"getSymbolCount") then return s end
end
function M.read()
 local s=symbols()
 if not s then return nil,"world map symbols unavailable" end
 local count=call(s,"getSymbolCount")
 if type(count)~="number" then return nil,"world map count unavailable" end
 local notes={}
 local missingCoordinates=0
 for i=0,math.min(math.max(0,count),500)-1 do
   local symbol=call(s,"getSymbolByIndex",i)
   if symbol then
     local text
     if call(symbol,"isTexture")==true then
        local key=call(symbol,"getSymbolID")
        if type(key)=="string" and #key<=80 then text="ICON:"..key end
     else
        text=call(symbol,"getUntranslatedText") or
            call(symbol,"getTranslatedText") or call(symbol,"getText")
     end
     local x=call(symbol,"getWorldX")
     local y=call(symbol,"getWorldY")
     if type(text)=="string" and type(x)=="number" and
        type(y)=="number" then
       notes[#notes+1]={text=text,x=x,y=y,z=0}
     elseif type(text)=="string" then
       missingCoordinates=missingCoordinates+1
     end
   end
 end
 if missingCoordinates>0 and #notes==0 then
    return nil,"map symbols do not expose world coordinates"
 end
 return Territory.import(notes),nil
end
function M.update(player)
 if not player then return false end
 local md=call(player,"getModData")
 if not md then return false end
 local data,reason=M.read()
 if not data then
   if type(md.SupraNPC_Territory)=="table" then
      M.current=md.SupraNPC_Territory
   end
   return false,reason
 end
 local function digest(d)
   local parts={}
   for _,n in ipairs(d.notes) do
      parts[#parts+1]=n.text..":"..n.x..":"..n.y
   end
   return table.concat(parts,"|")
 end
 local signature=digest(data)
 if M.signature~=signature then
   M.signature=signature
   M.current=data
   md.SupraNPC_Territory=data
   local b=data.base
   Core.log("MAP_KNOWLEDGE sync notes="..#data.notes..
     " base="..(b and b.defined or "NONE"))
 end
 M.sourceAvailable=true
 return true
end
function M.get(player)
 if player then
   local md=call(player,"getModData")
   if md and type(md.SupraNPC_Territory)=="table" then
      return md.SupraNPC_Territory
   end
 end
 return M.current
end
function M.reset() M.current=Territory.new();M.signature=nil;M.sourceAvailable=false end
return M
