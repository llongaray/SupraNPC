-- SupraNPC: navigation with safe, bounded door/window handling for B42.
-- Never unlock, smash, climb, teleport, open remote doors or cross walls.
local N={blocked={},repathRadius=16,maxVisited=640,ttlMs=14000}
local function call(obj,key,...)
 if not obj then return nil end
 local args={...}
 local ok,value=pcall(function()
  if obj[key] then return obj[key](obj,unpack(args)) end
 end)
 if ok then return value end
 return nil
end
local function now()
 local ok,n=pcall(function() return getTimestampMs and getTimestampMs() end)
 return ok and type(n)=="number" and n or 0
end
local function valid(n) return type(n)=="number" and n==n end
local function opened(o)
 return call(o,"IsOpen")==true or call(o,"isOpen")==true
end
local function oneWay(a,b,method)
 return call(a,method,b) or call(b,method,a)
end
function N.edge(a,b)
 if not a or not b then return {kind="UNKNOWN",passable=false} end
 local ax,ay,az=call(a,"getX"),call(a,"getY"),call(a,"getZ")
 local bx,by,bz=call(b,"getX"),call(b,"getY"),call(b,"getZ")
 if not valid(ax) or not valid(bx) or not valid(ay) or not valid(by) or
    not valid(az) or not valid(bz) or az~=bz or
    math.abs(ax-bx)+math.abs(ay-by)~=1 then
   return {kind="UNKNOWN",passable=false}
 end
 local win=oneWay(a,b,"getWindowTo") or oneWay(a,b,"getWindowThumpableTo")
 if win then
   return {kind="WINDOW",object=win,passable=false,
       open=opened(win),canTry=not opened(win) and
       call(win,"isLocked")~=true and call(win,"isPermaLocked")~=true and
       call(win,"isBarricaded")~=true and call(win,"isDestroyed")~=true}
 end
 local door=oneWay(a,b,"getDoorTo")
 if door then
   local open=opened(door)
   local safe=call(door,"isLocked")~=true and
       call(door,"isLockedByKey")~=true and
       call(door,"isBarricaded")~=true and
       call(door,"isObstructed")~=true
   return {kind="DOOR",object=door,open=open,passable=open,
       canTry=not open and safe}
 end
 if call(a,"isWallTo",b)==true or call(b,"isWallTo",a)==true or
     call(a,"isHoppableTo",b)==true or call(b,"isHoppableTo",a)==true or
     call(a,"isBlockedTo",b)==true or call(b,"isBlockedTo",a)==true then
   return {kind="WALL",passable=false}
 end
 return {kind="OPEN",passable=true}
end
function N.isIgnored(id,obj)
 local mem=N.blocked[id]
 return obj~=nil and mem and mem[obj] and mem[obj]>now() or false
end
function N.ignore(id,obj)
 if obj==nil or type(id)~="string" then return end
 N.blocked[id]=N.blocked[id] or {}
 N.blocked[id][obj]=now()+N.ttlMs
end
function N.tryOpen(id,actor,edge)
 if not edge or not edge.object then return false,"no barrier" end
 if edge.kind~="DOOR" and edge.kind~="WINDOW" then
    return false,"not a door/window"
 end
 if edge.open then return true,"already open" end
 if not edge.canTry or N.isIgnored(id,edge.object) then
    return false,"locked, barred or recently failed"
 end
 local loc=call(edge.object,"getSquare")
 local d
 if loc then
   local dx=(call(loc,"getX") or 999)-(call(actor,"getX") or -999)
   local dy=(call(loc,"getY") or 999)-(call(actor,"getY") or -999)
   d=math.sqrt(dx*dx+dy*dy)
 end
 -- Only handle a portal in the actor's own tile/one neighboring tile.
 if not d or d>1.85 then return false,"portal too far" end
 local method=edge.kind=="DOOR" and "ToggleDoor" or "ToggleWindow"
 local ok,err=pcall(function()
    if not edge.object[method] then error("toggle unavailable") end
    edge.object[method](edge.object,actor)
 end)
 if not ok or not opened(edge.object) then
    N.ignore(id,edge.object)
    return false,ok and "still closed" or tostring(err)
 end
 return true,"opened"
end
function N.clear(id)
 N.blocked[id]=nil
end
-- Opening a window does not authorize a crossing (climbing not supported).
-- Called only in a local, already-failed route; one attempt then use detour.
function N.tryNearbyWindow(actor,tx,ty,id)
 local cell=getCell and getCell()
 if not cell then return false end
 local ax,ay,az=call(actor,"getX"),call(actor,"getY"),call(actor,"getZ")
 if not valid(ax) or not valid(ay) or not valid(az) then return false end
 local x,y,z=math.floor(ax),math.floor(ay),math.floor(az)
 local sq=call(cell,"getGridSquare",x,y,z)
 if not sq then return false end
 local dirs={}
 if tx>x then dirs[#dirs+1]={1,0} elseif tx<x then dirs[#dirs+1]={-1,0} end
 if ty>y then dirs[#dirs+1]={0,1} elseif ty<y then dirs[#dirs+1]={0,-1} end
 for _,dir in ipairs(dirs) do
   local neighbor=call(cell,"getGridSquare",x+dir[1],y+dir[2],z)
   local edge=N.edge(sq,neighbor)
   if edge.kind=="WINDOW" and edge.canTry and
       not N.isIgnored(id,edge.object) then
     local ok,reason=N.tryOpen(id,actor,edge)
     -- Even opened windows require a separate climbing mechanic.
     N.ignore(id,edge.object)
     return ok,ok and "window opened; reroute" or reason
   end
 end
 return false
end
function N.canCross(a,b,id,allowDoor)
 local e=N.edge(a,b)
 if e.passable then return true,e end
 if e.kind=="DOOR" and allowDoor and e.canTry and
    not N.isIgnored(id,e.object) then return true,e end
 return false,e
end
local dirs={{1,0},{0,1},{-1,0},{0,-1}}
-- Bounded search: only loaded squares, no diagonals through corners.
-- Returns a one-tile waypoint; retries the route after an opened door.
function N.next(actor,tx,ty,tz,id,free,range,avoidPortals)
 if not actor or not getCell or not valid(tx) or not valid(ty) or
    not valid(tz) or type(free)~="function" then return nil,"invalid goal" end
 local cell=getCell()
 if not cell then return nil,"no cell" end
 local ax,ay,az=call(actor,"getX"),call(actor,"getY"),call(actor,"getZ")
 if not valid(ax) or not valid(ay) or not valid(az) or
    math.floor(tz)~=math.floor(az) then return nil,"different floor" end
 local bx,by,z=math.floor(ax),math.floor(ay),math.floor(az)
 local start=call(cell,"getGridSquare",bx,by,z)
 if not start then return nil,"unloaded starting square" end
 local limit=N.repathRadius
 local q={{sq=start,x=bx,y=by,parent=nil,portal=nil}}
 local first,last=1,1
 local marked={[bx..":"..by]=true}
 local best,bestD=nil,math.huge
 local reached=false
 local targetSquare=call(cell,"getGridSquare",math.floor(tx),math.floor(ty),z)
 range=range or 1.3
 while first<=last and first<=N.maxVisited do
   local node=q[first];first=first+1
   local dd=math.sqrt((node.x+0.5-tx)^2+(node.y+0.5-ty)^2)
   local goalVisible=true
   if targetSquare and node.sq~=targetSquare then
     local dx=math.abs(node.x-math.floor(tx))
     local dy=math.abs(node.y-math.floor(ty))
     if dx+dy==1 then
       goalVisible=N.canCross(node.sq,targetSquare,id,false)
     end
   end
   if dd<=range and goalVisible then best=node;reached=true;break end
   if dd<bestD and goalVisible then best,bestD=node,dd end
   for _,d in ipairs(dirs) do
     local x,y=node.x+d[1],node.y+d[2]
     local key=x..":"..y
     if not marked[key] and math.abs(x-bx)+math.abs(y-by)<=limit then
       marked[key]=true
       local sq=call(cell,"getGridSquare",x,y,z)
       if sq and (free(sq,actor) or
          (math.floor(tx)==x and math.floor(ty)==y)) then
         local yes,e=N.canCross(node.sq,sq,id,not avoidPortals)
         if yes then
           last=last+1
           q[last]={sq=sq,x=x,y=y,parent=node,portal=e}
         end
       end
     end
   end
 end
 if not reached and math.sqrt((bx+0.5-tx)^2+(by+0.5-ty)^2)<limit-2 then
    if not avoidPortals then N.tryNearbyWindow(actor,tx,ty,id) end
    return nil,"no accessible route"
 end
 if not best or best==q[1] then
   return nil,best==q[1] and "already near" or "no accessible route"
 end
 local step=best
 while step.parent and step.parent~=q[1] do step=step.parent end
 local edge=step.portal
 if edge and edge.kind=="DOOR" and not edge.open then
   local ok,why=N.tryOpen(id,actor,edge)
   if not ok then
      return nil,"door failed: "..tostring(why)
   end
   return nil,"door opened"
 end
 if edge and not edge.passable then return nil,"portal blocked" end
 return step.sq,"waypoint"
end
-- Check direct attack reach, which may be visually clear through a window.
function N.attackAccessible(actor,target)
 if not actor or not target then return false end
 local ax,ay,az=call(actor,"getX"),call(actor,"getY"),call(actor,"getZ")
 local tx,ty,tz=call(target,"getX"),call(target,"getY"),call(target,"getZ")
 if not valid(ax) or not valid(ay) or not valid(tx) or not valid(ty)
    or not valid(az) or not valid(tz) or math.floor(az)~=math.floor(tz) then
    return false end
 local x,y,gx,gy=math.floor(ax),math.floor(ay),math.floor(tx),math.floor(ty)
 if x==gx and y==gy then return true end
 local cell=getCell and getCell()
 if not cell then return false end
 local sq=call(cell,"getGridSquare",x,y,math.floor(az))
 if not sq then return false end
 -- For a short melee hit, check every edge towards the target.
 local dx,dy=gx-x,gy-y
 if math.abs(dx)>2 or math.abs(dy)>2 then return false end
 local function path(xfirst)
    local xx,yy=x,y
    local current=sq
    local function walkStep(nx,ny)
       local nextSq=call(cell,"getGridSquare",nx,ny,math.floor(az))
       if not nextSq then return false end
       local yes=N.canCross(current,nextSq,nil,false)
       if not yes then return false end
       current=nextSq;xx,yy=nx,ny
       return true
    end
    while xx~=gx or yy~=gy do
      local nx,ny=xx,yy
      if (xfirst and xx~=gx) or yy==gy then
        nx=xx+(gx>xx and 1 or -1)
      else
        ny=yy+(gy>yy and 1 or -1)
      end
      if not walkStep(nx,ny) then return false end
    end
    return true
 end
 return path(true) or path(false)
end
return N
