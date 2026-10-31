-- Detection and equipment assessment for Build 42. No external AI.
local P={VIEW_RANGE=12,CLOSE_RANGE=3.2,THREAT_RANGE=6.0,MAX_OBJECTS=900}
local function call(o,m,...)
 if not o then return nil end
 local a={...};local ok,v=pcall(function() if o[m] then return o[m](o,unpack(a)) end end)
 if ok then return v end
end
local function finite(x)
 return type(x)=="number" and x==x and x~=math.huge and x~=-math.huge
end
local function zombie(o)
 if not o or not instanceof then return false end
 local ok,yes=pcall(instanceof,o,"IsoZombie")
 return ok and yes==true and call(o,"isDead")==false
end
local function distance(a,b)
 local x,y,z=call(a,"getX"),call(a,"getY"),call(a,"getZ")
 local u,v,w=call(b,"getX"),call(b,"getY"),call(b,"getZ")
 if not finite(x) or not finite(y) or not finite(z) or
    not finite(u) or not finite(v) or not finite(w) or
    math.floor(z)~=math.floor(w) then return nil end
 return math.sqrt((x-u)^2+(y-v)^2),u-x,v-y
end
P.distance=distance
function P.equipment(actor)
 local w=call(actor,"getPrimaryHandItem")
 local info={category="UNARMED",power=0.8,weapon=nil}
 if not w or not instanceof then return info end
 local ok,yes=pcall(instanceof,w,"HandWeapon")
 if not ok or not yes or call(w,"isBroken")==true or call(w,"isBareHands")==true then
    return info end
 if call(w,"isRanged")==true or call(w,"isAimedFirearm")==true then
    info.category="FIREARM"; info.weapon=w
    info.power=0.7 -- no autonomous gunshot AI yet; not counted as melee support
    if call(w,"isJammed")==true or call(w,"getCurrentAmmoCount")==0 then
       info.category="FIREARM_EMPTY";info.power=0.5 end
 else
    info.category="MELEE";info.weapon=w;info.power=2.0
 end
 return info
end
local function forward(a)
 local fx,fy=call(a,"getForwardDirectionX"),call(a,"getForwardDirectionY")
 if not finite(fx) or not finite(fy) then
    local v=call(a,"getForwardDirection")
    fx,fy=call(v,"getX"),call(v,"getY")
 end
 if not finite(fx) or not finite(fy) then return nil end
 local length=math.sqrt(fx*fx+fy*fy)
 if length<0.01 then return nil end
 return fx/length,fy/length
end
function P.canPerceive(actor,target,d,dx,dy)
 if not d or d>P.VIEW_RANGE then return false end
 -- Close quarter 360-degree awareness for immediate self-defense.
 if d>P.CLOSE_RANGE then
   local fx,fy=forward(actor)
   if fx then
     -- 130-degree vision funnel (half-angle 65 degrees).
     local cosine=(fx*dx+fy*dy)/d
     if cosine<0.4226 then return false end
   end
 end
 -- Engine has the final word on walls/occlusion.
 return call(actor,"CanSee",target)==true
end
local function isDown(z)
 return call(z,"isGettingUp")~=true and call(z,"isCrawling")~=true and
   (call(z,"isOnFloor")==true or call(z,"isProne")==true)
end
P.isDown=isDown
function P.observe(actor,player,team)
 local result={standing=0,down=0,nearStanding=0,nearDown=0,seen=0,
  nearest=nil,nearestDistance=nil,nearestDown=nil,nearestDownDistance=nil,
  visible=false,downVisible=false,ally=false,allies=0,groupPower=0,
  armed=0,unarmed=0,npcWeapon=P.equipment(actor),
  nearestThreat=nil,firstVisible=nil}
 if not actor or call(actor,"isDead")~=false then return result end
 local allies={}
 local function addAlly(candidate)
    if not candidate or candidate==actor or allies[candidate] or
       call(candidate,"isDead")~=false then return end
    local d=distance(actor,candidate)
    if not d or d>5 then return end
    allies[candidate]=true;result.allies=result.allies+1
    local eq=P.equipment(candidate)
    result.groupPower=result.groupPower+eq.power
    if eq.category=="MELEE" then result.armed=result.armed+1
    else result.unarmed=result.unarmed+1 end
 end
 addAlly(player)
 for _,entry in pairs(type(team)=="table" and team or {}) do
    if type(entry)=="table" then addAlly(entry.actor) end
 end
 result.ally=result.allies>0
 result.groupPower=result.groupPower+result.npcWeapon.power
 local cell=getCell and getCell()
 if not cell then return result end
 local scanned=0
 local seen={}
 local function consider(target)
    if not zombie(target) or seen[target] then return end
    seen[target]=true
    local d,dx,dy=distance(actor,target)
    if not d or not P.canPerceive(actor,target,d,dx,dy) then return end
    result.seen=result.seen+1
    if not result.firstVisible then result.firstVisible=target end
    if isDown(target) then
       result.down=result.down+1
       if d<=P.THREAT_RANGE then
          result.nearDown=result.nearDown+1
          if not result.nearestDownDistance or d<result.nearestDownDistance then
             result.nearestDownDistance=d;result.nearestDown=target
             result.downVisible=true
          end
       end
    else
       result.standing=result.standing+1
       if d<=P.THREAT_RANGE then
          result.nearStanding=result.nearStanding+1
          if not result.nearestDistance or d<result.nearestDistance then
             result.nearestDistance=d;result.nearest=target;result.visible=true
          end
       end
    end
 end
 -- Prefer loaded zombie list (avoids 625 grid-square lookups per NPC).
 local zs=call(cell,"getZombieList")
 local n=call(zs,"size")
 if finite(n) and n>=0 then
    for i=0,math.min(n,P.MAX_OBJECTS)-1 do consider(call(zs,"get",i)) end
 else
    local x,y,z=call(actor,"getX"),call(actor,"getY"),call(actor,"getZ")
    if not finite(x) or not finite(y) or not finite(z) then return result end
    local bx,by,bz=math.floor(x),math.floor(y),math.floor(z)
    for ox=-12,12 do
       for oy=-12,12 do
          if ox*ox+oy*oy<=144 then
             local sq=call(cell,"getGridSquare",bx+ox,by+oy,bz)
             local objects=call(sq,"getMovingObjects")
             local size=call(objects,"size")
             if finite(size) and size>=0 and size<=40 then
                for i=0,size-1 do
                   scanned=scanned+1
                   if scanned>P.MAX_OBJECTS then return result end
                   consider(call(objects,"get",i))
                end
             end
          end
       end
    end
 end
 return result
end
-- Decision heuristic; these are not measured death probabilities.
function P.risk(obs,health)
 local count=obs.nearStanding or 0
 local strength=obs.groupPower or 0.8
 local unarmedGroup=(obs.npcWeapon and obs.npcWeapon.category~="MELEE") and
     (obs.armed or 0)==0
 local critical=(type(health)=="number" and health<35)
 local escape=(count>=3 and (not obs.ally or strength<count*1.1 or
     unarmedGroup)) or (count>=2 and unarmedGroup) or
     (critical and count>=1)
 return {retreat=escape,unarmed=unarmedGroup,critical=critical,
     severity=count/math.max(0.1,strength)}
end
return P
