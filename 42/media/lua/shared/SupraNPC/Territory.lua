-- Pure Lua 5.1 territory model. Shared player annotations, no claim of verified safety.
local T={MAX=120}
local aliases={BASE="BASE",CASA="BASE",HOME="BASE",LOOT="LOOT",SAQUE="LOOT",LOTEAR="LOOT",CLEAR="CLEAR",LIMPAR="CLEAR",DANGER="DANGER",PERIGO="DANGER",RALLY="RALLY",ENCONTRO="RALLY",SUPPLY="SUPPLY",HOSPITAL="HOSPITAL",FARMACIA="HOSPITAL"}
local function finite(v) return type(v)=="number" and v==v and v>-1000000 and v<1000000 end
function T.classify(text)
 if type(text)~="string" then return "NOTE" end
 local upper=text:upper():gsub("^%s+",""):gsub("%s+$","")
 local kind,corner=upper:match("^NPC%s*:%s*([%w_]+)%s*:%s*([AB])$")
 if kind and aliases[kind] then return aliases[kind],corner end
 kind=upper:match("^NPC%s*:%s*([%w_]+)")
 return aliases[kind] or "NOTE",nil
end
function T.new() return {schema=1,notes={},base=nil} end
function T.import(notes)
 local data=T.new();local corners={}
 if type(notes)~="table" then return data end
 for _,n in ipairs(notes) do
  if #data.notes>=T.MAX then break end
  if type(n)=="table" and type(n.text)=="string" and #n.text>0 and #n.text<=120 and finite(n.x) and finite(n.y) and finite(n.z or 0) then
   local kind,corner=T.classify(n.text)
   local r={text=n.text,kind=kind,corner=corner,x=math.floor(n.x),y=math.floor(n.y),z=math.floor(n.z or 0)}
   data.notes[#data.notes+1]=r
   if kind=="BASE" then
    if corner then corners[corner]=r
    elseif not data.base then
     data.base={x=r.x,y=r.y,z=r.z,x1=r.x-3,x2=r.x+3,y1=r.y-3,y2=r.y+3,defined="POINT",verified=false}
    end
   end
  end
 end
 local a,b=corners.A,corners.B
 if a and b and a.z==b.z then
  local x1,x2=math.min(a.x,b.x),math.max(a.x,b.x)
  local y1,y2=math.min(a.y,b.y),math.max(a.y,b.y)
  if (x2-x1+1)*(y2-y1+1)<=10000 then
   data.base={x=math.floor((x1+x2)/2),y=math.floor((y1+y2)/2),z=a.z,
     x1=x1,x2=x2,y1=y1,y2=y2,defined="RECT",verified=false}
  end
 end
 return data
end
function T.inside(data,x,y,z)
 local b=type(data)=="table" and data.base
 return b and finite(x) and finite(y) and finite(z) and math.floor(z)==b.z and x>=b.x1 and x<=b.x2 and y>=b.y1 and y<=b.y2 or false
end
function T.basePoint(data)
 local b=type(data)=="table" and data.base
 if b then return {x=b.x+0.5,y=b.y+0.5,z=b.z} end
end
function T.knowledge(data)
 local result={}
 for _,n in ipairs(type(data)=="table" and type(data.notes)=="table" and data.notes or {}) do result[n.kind]=(result[n.kind] or 0)+1 end
 return result
end
return T
