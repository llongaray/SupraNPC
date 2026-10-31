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
print("[SupraNPC] speech_spec: OK")
