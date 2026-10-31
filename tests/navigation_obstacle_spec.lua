package.path="42/media/lua/client/?.lua;42/media/lua/shared/?.lua;"..package.path
local clock=1000;getTimestampMs=function() return clock end
local N=require("SupraNPC/NPCNavigation")
local allowDetour=false
local tiles={}
local function tile(x,y)
 local key=x..":"..y
 if tiles[key] then return tiles[key] end
 local s={x=x,y=y}
 function s:getX() return self.x end
 function s:getY() return self.y end
 function s:getZ() return 0 end
 function s:getMovingObjects() return {size=function() return 0 end} end
 function s:TreatAsSolidFloor() return true end
 function s:isFree() return true end
 function s:isBlockedTo(other)
    if other.y~=self.y and not allowDetour then return true end
    return false
 end
 function s:getDoorTo(other)
    if self.y==1 and other.y==1 and
        ((self.x==1 and other.x==2) or
         (self.x==2 and other.x==1)) then
       return _G.portalKind=="door" and _G.portal or nil
    end
 end
 function s:getWindowTo(other)
    if self.y==1 and other.y==1 and
       ((self.x==1 and other.x==2) or
        (self.x==2 and other.x==1)) then
       return _G.portalKind=="window" and _G.portal or nil
    end
 end
 tiles[key]=s;return s
end
getCell=function() return {
 getGridSquare=function(_,x,y,z)
   if x>=0 and x<=4 and y>=0 and y<=2 and z==0 then
      return tile(x,y)
   end
 end
} end
local actor={x=0.5,y=1.5}
function actor:getX() return self.x end
function actor:getY() return self.y end
function actor:getZ() return 0 end
local target={x=2.5,y=1.5}
function target:getX() return self.x end
function target:getY() return self.y end
function target:getZ() return 0 end
local function free(s) return s~=nil end
local function portal(kind,locked,works)
 _G.portalKind=kind
 local p={open=false,locked=locked,tries=0}
 p.square=tile(2,1)
 function p:getSquare() return self.square end
 function p:IsOpen() return self.open end
 function p:isLocked() return self.locked end
 function p:isLockedByKey() return false end
 function p:isBarricaded() return false end
 function p:isPermaLocked() return false end
 function p:ToggleDoor(who)
    assert(who==actor);self.tries=self.tries+1
    if works and not self.locked then self.open=true end
 end
 p.ToggleWindow=p.ToggleDoor
 _G.portal=p
 return p
end
local door=portal("door",false,true)
local nextSq,reason=N.next(actor,3.5,1.5,0,"npc",free,1.3)
assert(nextSq==tile(1,1) and reason=="waypoint")
actor.x=1.5
-- Escape must never open closed doors, even when unlocked.
nextSq,reason=N.next(actor,3.5,1.5,0,"npc",free,1.3,true)
assert(nextSq==nil and reason=="no accessible route" and door.tries==0)
nextSq,reason=N.next(actor,3.5,1.5,0,"npc",free,1.3)
assert(nextSq==nil and reason=="door opened" and door.open and door.tries==1)
assert(N.attackAccessible(actor,target))
nextSq=N.next(actor,3.5,1.5,0,"npc",free,1.3)
assert(nextSq==tile(2,1))
-- Locked door cannot be unlocked by NPC or crossed.
N.clear("npc")
door=portal("door",true,false)
assert(not N.attackAccessible(actor,target))
nextSq,reason=N.next(actor,3.5,1.5,0,"npc",free,1.3)
assert(nextSq==nil and reason=="no accessible route" and door.tries==0)
-- A closed window can be opened once, but does NOT become walkable.
N.clear("npc")
local window=portal("window",false,true)
window.canClimbThrough=function() return true end
actor.climbThroughWindow=function(self,w)
    self.climbCount=(self.climbCount or 0)+1
    assert(w==window)
end
nextSq,reason=N.next(actor,3.5,1.5,0,"npc",free,1.3)
assert(nextSq==nil and reason=="window opened")
assert(window.open and window.tries==1)
assert(not N.attackAccessible(actor,target))
nextSq,reason=N.next(actor,3.5,1.5,0,"npc",free,1.3)
assert(nextSq==nil and reason=="window climbing" and actor.climbCount==1)
assert(N.isClimbing("npc",actor))
actor.x=2.5
assert(not N.isClimbing("npc",actor))
actor.x=1.5
nextSq=N.next(actor,3.5,1.5,0,"npc",free,1.3)
assert(window.tries==1 and actor.climbCount==1)
-- A locked door with a detour must produce an alternate route.
N.clear("npc")
door=portal("door",true,false)
allowDetour=true
nextSq,reason=N.next(actor,3.5,1.5,0,"npc",free,1.3)
assert(nextSq and nextSq:getY()~=1)
assert(door.tries==0)
print("[SupraNPC] navigation_obstacle_spec: OK")
