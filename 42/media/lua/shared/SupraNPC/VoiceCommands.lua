-- PT-BR voice-typing command grammar. Pure Lua; no microphone or file access.
-- In Windows use Win+H inside the SupraNPC command textbox.
local V={}
local mapping={
 {"á","a"},{"à","a"},{"â","a"},{"ã","a"},{"ä","a"},
 {"é","e"},{"ê","e"},{"è","e"},{"í","i"},{"ì","i"},
 {"ó","o"},{"ô","o"},{"õ","o"},{"ò","o"},{"ú","u"},
 {"ü","u"},{"ç","c"}
}
function V.normalize(phrase)
 if type(phrase)~="string" or #phrase>200 then return "" end
 local s=phrase:lower()
 for _,pair in ipairs(mapping) do s=s:gsub(pair[1],pair[2]) end
 s=s:gsub("[^%w%s]"," "):gsub("%s+"," ")
 return (s:gsub("^%s+",""):gsub("%s+$",""))
end
local function has(s,phrases)
 for _,p in ipairs(phrases) do
    if s:find(" "..p.." ",1,true) then return true end
 end
 return false
end
function V.parse(phrase,profiles)
 local text=V.normalize(phrase)
 if text=="" then return nil,"frase vazia ou longa" end
 local w=" "..text.." "
 if has(w,{"nao","cancelar todas","desconsidera"}) then
    return nil,"negacao ou cancelamento ambiguo"
 end
 local cmd,option
 if has(w,{"postura agressiva","modo agressivo","fica agressivo","seja agressivo","agressivo"}) then
    cmd,option="STANCE","AGGRESSIVE"
 elseif has(w,{"postura defensiva","modo defensivo","fica defensivo","defensivo"}) then
    cmd,option="STANCE","DEFENSIVE"
 elseif has(w,{"postura passiva","modo passivo","fica passivo","passivo"}) then
    cmd,option="STANCE","PASSIVE"
 elseif has(w,{"guarda minha posicao","protege minha posicao","vigia onde estou","guarda meu local"}) then
    cmd,option="GUARD","PLAYER"
 elseif has(w,{"guarda aqui","guarde aqui","vigia aqui","protege esta posicao","guarde essa posicao"}) then
    cmd,option="GUARD","NPC"
 elseif has(w,{"me segue","me sigam","siga me","siga-me","vem comigo","venha comigo","vamos juntos"}) then
    cmd="FOLLOW"
 elseif has(w,{"aguarda aqui","aguarde aqui","espera aqui","esperem aqui","fica aqui","fique aqui","fica parado","pare aqui"}) then
    cmd="IDLE"
 else return nil,"comando nao reconhecido" end
 if type(profiles)~="table" then return nil,"equipe indisponivel" end
 local chosen={}
 local all=has(w,{"todos","todas","pessoal","equipe","companheiros","gente"})
 for _,p in ipairs(profiles) do
    local name=V.normalize(p.firstName or "")
    local full=V.normalize((p.firstName or "").." "..(p.lastName or ""))
    if type(p.id)=="string" and (all or
       (name~="" and has(w,{name})) or
       (full~="" and has(w,{full}))) then
       chosen[#chosen+1]=p.id
    end
 end
 if #chosen==0 and #profiles==1 and type(profiles[1].id)=="string" then
    chosen[1]=profiles[1].id
 end
 if #chosen==0 then return nil,"diga o nome do NPC ou todos" end
 return {targets=chosen,cmd=cmd,option=option,utterance=text}
end
return V
