-- B42 mocked: shove -> queda confirmada -> aproximar -> atacar -> resume.
package.path="42/media/lua/client/?.lua;42/media/lua/shared/?.lua;"..package.path
local time=10000
getTimestampMs=function() return time end
ZombRand=function(n) return 0 end -- teste: empurrao derruba
instanceof=function(o,typ) return o and o.kind==typ end
local sq={}
local objects={}
sq.getMovingObjects=function()
    return {size=function() return #objects end,
        get=function(_,i) return objects[i+1] end}
end
getCell=function() return {getGridSquare=function() return sq end} end
local npc={kind="IsoPlayer",x=10,y=10,dead=false}
function npc:getX() return self.x end
function npc:getY() return self.y end
function npc:getZ() return 0 end
function npc:isDead() return self.dead end
function npc:getCurrentSquare() return sq end
function npc:CanSee() return true end
function npc:faceThisObject() end
function npc:canPerformHandToHandCombat() return true end
local weapon={kind="HandWeapon",getMinDamage=function() return 0.3 end,
    getMaxDamage=function() return 0.5 end,getMaxRange=function() return 1.5 end,
    isAimedFirearm=function() return false end,isBroken=function() return false end}
function npc:getPrimaryHandItem() return weapon end
local target={kind="IsoZombie",x=11,y=10.2,dead=false,down=false,hp=0.8,hits=0}
function target:getX() return self.x end
function target:getY() return self.y end
function target:getZ() return 0 end
function target:isDead() return self.dead end
function target:getCurrentSquare() return sq end
function target:isOnFloor() return self.down end
function target:isProne() return self.down end
function target:isGettingUp() return false end
function target:knockDown()
    self.down=true
end
function target:Hit(w,who,damage)
    assert(w==weapon and who==npc)
    assert(self.down)
    self.hits=self.hits+1
    self.hp=self.hp-damage
    if self.hp<=0 then self.dead=true end
    return damage
end
local friendly={kind="IsoPlayer"}
objects={npc,target,friendly}
local move={active=false,starts=0,cancels=0}
local Walking={
    active=function() return move.active end,
    cancel=function() move.active=false;move.cancels=move.cancels+1 end,
    pickAround=function() return sq end,
    pickRetreat=function() return sq end,
    start=function() move.active=true;move.starts=move.starts+1;return true end
}
package.loaded["SupraNPC/NPCWalking"]=Walking
package.loaded["SupraNPC/NPCNavigation"]={attackAccessible=function() return true end,next=function() return sq,"waypoint" end,clear=function() end}

local Orders=require("SupraNPC/Orders")
local D=require("SupraNPC/NPCDefense")
local entry={actor=npc,profile={id="A"},state=Orders.new("FOLLOW")}
assert(D.scan(npc)==target)
assert(D.update(entry)==true)
assert(entry.state.active=="SELF_DEFEND" and entry.state.requested=="FOLLOW")
assert(target.down and target.hits==0)
time=time+1000
D.update(entry)
assert(entry.navStatus=="STOMP" and target.hits==1)
-- Piso nativo pode funcionar a ate 1.35 tile; concluir no segundo golpe.
npc.x=10.4
time=time+1100
D.update(entry)
assert(target.dead and target.hits==2)
assert(D.hit(npc,friendly)==false) -- jamais bater no jogador
time=time+1100
assert(D.update(entry)==false)
assert(entry.state.active=="FOLLOW" and D.STATES.A==nil)
-- Shove pode falhar: zumbi continua em pe, proxima acao e BACKSTEP.
target.dead=false;target.down=false;target.hp=1;target.hits=0
npc.x=10
local entry2={actor=npc,profile={id="B"},state=Orders.new("IDLE")}
ZombRand=function() return 99 end
D.update(entry2)
assert(not target.down and target.hits==0)
time=time+1000
D.update(entry2)
assert(entry2.navStatus=="SHOVE" and target.hits==0)
-- Com varios empurroes resistidos e contato muito proximo, recuar.
npc.x=10.6
for i=1,3 do time=time+1000;D.update(entry2) end
assert(entry2.navStatus=="BACKSTEP" or entry2.navStatus=="SHOVE")
-- Sem visibilidade ou outro andar nao e alvo.
npc.CanSee=function() return false end
assert(D.hit(npc,target)==false)
target.getZ=function() return 1 end
assert(D.observe(npc).standing==0)
D.clear()
print("[SupraNPC] npc_defense_spec: OK")
