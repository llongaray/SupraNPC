-- Verificacao dos textos por acao, sem criar NPC nem alterar o player.
package.path="42/media/lua/client/?.lua;42/media/lua/shared/?.lua;"..package.path
local Speech=require("SupraNPC/NPCSpeech")
for _,command in ipairs({"FOLLOW","IDLE","GUARD"}) do
    local t=Speech.compose("Alex",command,command=="GUARD" and "PLAYER" or nil,true)
    assert(type(t)=="string" and t:find("Alex",1,true))
end
for _,stance in ipairs({"PASSIVE","DEFENSIVE","AGGRESSIVE"}) do
    local t=Speech.compose("Alex","STANCE",stance,true)
    assert(t:find("Alex",1,true))
end
assert(Speech.compose("Alex","FOLLOW",nil,false):find("nao consegui",1,true))
Speech.clear()
local actor={isDead=function() return false end}
getTimestampMs=function() return 25000 end
Speech.npcReply(actor,"FOLLOW",nil,true)
assert(#Speech.active==1 and Speech.active[1].actor==actor)
assert(Speech.active[1].text:find("indo",1,true) or
       Speech.active[1].text:find("voce",1,true))
assert(Speech.npcAlert(actor,"HORDE",true)==true)
assert(Speech.npcAlert(actor,"HORDE")==false) -- cooldown
assert(#Speech.active[1].queue==1)
Speech.npcReply(actor,"IDLE",nil,true)
assert(Speech.active[1].text:find("esperar",1,true) or
       Speech.active[1].text:find("ficar aqui",1,true))
assert(#Speech.active[1].queue==0)
Speech.clear()
assert(#Speech.active==0)
print("[SupraNPC] speech_spec: OK")
