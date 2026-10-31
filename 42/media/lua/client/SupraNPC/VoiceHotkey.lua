-- SupraNPC: binding configuravel e contrato do reconhecedor de fala.
-- Somente a UI/teclado estao implementados aqui. Lua vanilla do PZ nao
-- possui API de speech-to-text. NUNCA indicar microfone ativo sem backend.
local Core=require("SupraNPC/Constants")
local PTT={
    KEY_ID="SupraNPC_PushToTalk", DEFAULT_KEY=0,
    recognizer=nil, handler=nil, feedback=nil, active=false, keyDown=nil,
    state="UNAVAILABLE", reason="Reconhecedor de voz nao instalado"
}
local function gameCore()
    if type(getCore)~="function" then return nil end
    local ok,obj=pcall(getCore)
    if ok then return obj end
end
function PTT.registerBinding()
    if type(keyBinding)=="table" then
        local found=false
        for _,binding in ipairs(keyBinding) do
            if binding.value==PTT.KEY_ID then found=true; break end
        end
        if not found then
            table.insert(keyBinding,{value="[SupraNPC]"})
            table.insert(keyBinding,{value=PTT.KEY_ID,key=PTT.DEFAULT_KEY})
        end
    end
    local c=gameCore()
    -- ID deve existir antes da tela de teclas ser aberta. Nao substituir
    -- binds salvos; o padrao e DESVINCULADO para evitar conflito vanilla.
    if c and c.addKeyBinding and c.getKey then
        local ok,key=pcall(function() return c:getKey(PTT.KEY_ID) end)
        if ok and (key==nil or key==0) then
            pcall(function()
                c:addKeyBinding(PTT.KEY_ID,PTT.DEFAULT_KEY,0,false,false,false)
            end)
        end
    end
end
function PTT.getKey()
    local c=gameCore()
    if not c or not c.getKey then return 0 end
    local ok,k=pcall(function() return c:getKey(PTT.KEY_ID) end)
    return ok and type(k)=="number" and k or 0
end
function PTT.keyLabel()
    local k=PTT.getKey()
    if k==0 then return "SEM TECLA" end
    if Keyboard and Keyboard.getKeyName then
        local ok,label=pcall(function() return Keyboard.getKeyName(k) end)
        if ok and label then return tostring(label) end
    end
    return tostring(k)
end
function PTT.setHandler(handler)
    PTT.handler=type(handler)=="function" and handler or nil
end
function PTT.setFeedback(handler)
    PTT.feedback=type(handler)=="function" and handler or nil
end
local function notify(message)
    if PTT.feedback then pcall(PTT.feedback,message) end
    Core.log("VOICE-PTT: "..tostring(message))
end
function PTT.installRecognizer(provider)
    if type(provider)~="table" or type(provider.start)~="function" or
       type(provider.stop)~="function" then
       PTT.recognizer=nil
       PTT.state="UNAVAILABLE"
       PTT.reason="Reconhecedor de voz nao instalado"
       return false
    end
    PTT.recognizer=provider
    PTT.state="READY"
    PTT.reason=nil
    return true
end
function PTT.submitTranscript(text)
    if type(text)~="string" or text=="" or #text>200 then
        notify("Audio nao reconhecido")
        return false
    end
    PTT.state="READY"
    if not PTT.handler then return false end
    local ok,result=pcall(PTT.handler,text)
    if not ok then
        notify("Falha no comando: "..tostring(result))
        return false
    end
    return result==true
end
function PTT.press(key)
    if not Core.isSolo() or PTT.active then return false end
    if PTT.getKey()==0 then
        notify("Configure a tecla em Opcoes > Teclas > SupraNPC")
        return false
    end
    if not PTT.recognizer then
        PTT.state="UNAVAILABLE"
        notify("Microfone indisponivel: falta motor STT. Use o comando por texto.")
        return false
    end
    local ok,result,detail=pcall(PTT.recognizer.start,PTT.recognizer,
       function(text) PTT.submitTranscript(text) end)
    if not ok or result~=true then
        PTT.state="ERROR"
        PTT.reason=tostring(detail or result)
        notify("Falha ao iniciar reconhecimento: "..PTT.reason)
        return false
    end
    PTT.active=true
    PTT.keyDown=key
    PTT.state="LISTENING"
    notify("Ouvindo: solte a tecla para finalizar")
    return true
end
function PTT.release()
    if not PTT.active then return false end
    PTT.active=false
    PTT.keyDown=nil
    PTT.state="PROCESSING"
    local ok,result=pcall(PTT.recognizer.stop,PTT.recognizer)
    if not ok or result==false then
        PTT.state="ERROR"
        notify("Falha ao finalizar audio")
        return false
    end
    -- O provider chama submitTranscript ao concluir o reconhecimento.
    return true
end
function PTT.reset()
    if PTT.active then PTT.release() end
    PTT.active=false
    PTT.keyDown=nil
    PTT.state=PTT.recognizer and "READY" or "UNAVAILABLE"
end
function PTT.onKey(key)
    local bound=PTT.getKey()
    if bound~=0 and key==bound then PTT.press(key) end
end
function PTT.tick()
    if not PTT.active then return end
    if type(isKeyDown)=="function" and PTT.keyDown then
        local ok,held=pcall(isKeyDown,PTT.keyDown)
        if ok and held==false then PTT.release() end
    end
end
if Events then
    if Events.OnGameBoot then Events.OnGameBoot.Add(PTT.registerBinding) end
    if Events.OnKeyStartPressed then Events.OnKeyStartPressed.Add(PTT.onKey)
    elseif Events.OnKeyPressed then Events.OnKeyPressed.Add(PTT.onKey) end
    if Events.OnKeyReleased then
        Events.OnKeyReleased.Add(function(key)
            if PTT.active and key==PTT.keyDown then PTT.release() end
        end)
    end
    if Events.OnTick then Events.OnTick.Add(PTT.tick) end
end
PTT.registerBinding()
return PTT
