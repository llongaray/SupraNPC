-- Defesa: so zumbis, cooldown, interrupcao e retorno a FOLLOW.
package.path="42/media/lua/client/?.lua;42/media/lua/shared/?.lua;"..package.path
local time=10000
getTimestampMs=function() return time end
local square={}
local npc,player,enemy,friendly
instanceof=function(object,class)
    return type(object)=="table" and object.kind==class
end
local function coords(obj,x,y)
    obj.x=x;obj.y=y
    obj.getX=function(self) return self.x end
    obj.getY=function(self) return self.y end
    obj.getZ=function() return 0 end
    obj.getCurrentSquare=function() return square end
    obj.isDead=function(self) return self.dead==true end
end
npc={kind="IsoPlayer",dead=false}
coords(npc,10.2,10.3)
npc.CanSee=function() return true end
local weapon={kind="HandWeapon",
    getMinDamage=function() return 0.2 end,
    getMaxDamage=function() return 0.5 end,
    isAimedFirearm=function() return false end,
    isBroken=function() return false end}
npc.getPrimaryHandItem=function() return weapon end
npc.faceThisObject=function() end
player={kind="IsoPlayer"}
coords(player,15,16)
enemy={kind="IsoZombie",dead=false,hits=0}
coords(enemy,11.2,10.5)
enemy.Hit=function(self,w,attacker,damage,ignore,delta)
    assert(attacker==npc and w==weapon and ignore==false and delta==1.0)
    assert(damage>0 and damage<=0.65)
    self.hits=self.hits+1
    self.hp=(self.hp or 1.0)-damage
    if self.hp<=0 then self.dead=true end
    return damage
end
friendly={kind="IsoPlayer",dead=false}
coords(friendly,10.9,10.3)
local nearby={npc,enemy,friendly}
square.getMovingObjects=function()
    return {size=function() return #nearby end,
        get=function(_,i) return nearby[i+1] end}
end
local cell={getGridSquare=function() return square end}
getCell=function() return cell end
local cancelled={}
local Walking={
    active=function() return true end,
    cancel=function(id,why) cancelled[#cancelled+1]=why end,
    pickAround=function() return square end,
    start=function() return true end
}
package.loaded["SupraNPC/NPCWalking"]=Walking
local Core=require("SupraNPC/Constants")
local Orders=require("SupraNPC/Orders")
local Defense=require("SupraNPC/NPCDefense")
Core.isSolo=function() return true end
local entry={actor=npc,profile={id="P1"},state=Orders.new("FOLLOW")}
assert(Defense.scan(npc)==enemy) -- nunca selecionar IsoPlayer
assert(Defense.update(entry)==true)
assert(entry.state.requested=="FOLLOW")
assert(entry.state.active=="SELF_DEFEND")
assert(enemy.hits==1 and entry.navStatus=="DEFENDING")
assert(#cancelled>=1 and cancelled[1]=="autodefesa prioridade maxima")
-- Rate limit: nao aplicar dano em todo tick.
Defense.update(entry)
assert(enemy.hits==1)
time=time+1100
Defense.update(entry)
assert(enemy.hits==2)
-- Uma ordem dada durante o combate passa a ser pending.
assert(Orders.set(entry.state,"GUARD"))
assert(entry.state.active=="SELF_DEFEND")
assert(entry.state.requested=="GUARD")
-- Fim da ameaca restaura GUARD, sem esquecer pedido.
enemy.dead=true
assert(Defense.update(entry)==false)
assert(entry.state.active=="GUARD" and entry.state.requested=="GUARD")
assert(Defense.STATES.P1==nil)
-- Ataque nao deve acertar outro humano.
local hit,reason=Defense.hit(npc,friendly)
assert(hit==false and reason=="alvo invalido")
-- Sem arma nao inventar dano:
enemy.dead=false
npc.getPrimaryHandItem=function() return nil end
npc.getAttackingWeapon=function() return nil end
local ok,msg=Defense.hit(npc,enemy)
assert(ok==false and msg=="sem HandWeapon corpo a corpo")
npc.getPrimaryHandItem=function() return weapon end
-- Visibilidade é obrigatória para atingir atraves de tiles.
npc.CanSee=function() return false end
assert(Defense.hit(npc,enemy)==false)
npc.CanSee=function() return true end
-- Nao atacar zumbi de outro andar ou fora do raio.
enemy.getZ=function() return 1 end
assert(Defense.scan(npc)==nil)
enemy.getZ=function() return 0 end
Defense.clear()
print("[SupraNPC] npc_defense_spec: OK")
