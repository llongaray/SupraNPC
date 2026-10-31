package.path="42/media/lua/shared/?.lua;"..package.path
local V=require("SupraNPC/VoiceCommands")
local p={{id="one",firstName="Yong",lastName="Stallings"},
 {id="two",firstName="Alex",lastName="Su"}}
local a=assert(V.parse("Yong, me segue!",p))
assert(a.cmd=="FOLLOW" and #a.targets==1 and a.targets[1]=="one")
a=assert(V.parse("Todos me sigam",p))
assert(a.cmd=="FOLLOW" and #a.targets==2)
a=assert(V.parse("Alex, postura agressiva",p))
assert(a.cmd=="STANCE" and a.option=="AGGRESSIVE" and
 a.targets[1]=="two")
a=assert(V.parse("Yong, guarda aqui!",p))
assert(a.cmd=="GUARD" and a.option=="NPC")
a=assert(V.parse("Yong, guarda minha posição",p))
assert(a.cmd=="GUARD" and a.option=="PLAYER")
a=assert(V.parse("Yong aguarde aqui",p))
assert(a.cmd=="IDLE")
assert(V.parse("Yong não me segue",p)==nil)
assert(V.parse("Joao me segue",p)==nil)
assert(V.parse("todos podem explodir tudo",p)==nil)
assert(V.parse(string.rep("a",250),p)==nil)
print("[SupraNPC] voice_commands_spec: OK")
