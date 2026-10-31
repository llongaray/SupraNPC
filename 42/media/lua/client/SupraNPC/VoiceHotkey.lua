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
-- Keyboard.getKeyName indexes a fixed 256-element native array (0..255).
-- Some game/keybinding states expose synthetic action IDs (e.g. 10003)
-- instead of physical keycodes. Do not pass these to any LWJGL method:
-- a Java exception is logged even when Lua wraps the call in pcall().
local function physicalKey(key)
    return type(key)=="number" and key==key and key%1==0 and
        key>=1 and key<=255
end
-- PZ B42 encodes mouse buttons with BTN_OFFSET (10000); 10003
-- is Mouse Btn 3, not a broken keyboard key. Never pass it to Keyboard API.
local function mouseButton(key)
    if type(key)=="number" and key%1==0 and key>=10000 and key<=10007 then
        return key-10000
    end
    return nil
end
local function rawBinding()
    local c=gameCore()
    if not c or not c.getKey then return 0 end
    local ok,k=pcall(function() return c:getKey(PTT.KEY_ID) end)
    return ok and type(k)=="number" and k or 0
end
function PTT.getKey()
    local key=rawBinding()
    return (physicalKey(key) or mouseButton(key)~=nil) and key or 0
end
local lastLabelKey,lastLabel=nil,nil
function PTT.keyLabel()
    local key=rawBinding()
    if key==0 then return "SEM TECLA" end
    local mouse=mouseButton(key)
    if mouse then return "MOUSE BTN "..mouse end
    if not physicalKey(key) then return "RECONFIGURAR" end
    -- Cache results for each binding; render() is invoked every frame.
    if lastLabelKey==key and lastLabel then return lastLabel end
    local label=nil
    if Keyboard and Keyboard.getKeyName then
        local ok,result=pcall(function() return Keyboard.getKeyName(key) end)
        if ok and type(result)=="string" and result~="" then label=result end
    end
    lastLabelKey,lastLabel=key,label or ("TECLA "..tostring(key))
    return lastLabel
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
    PTT.mouseWasDown=false
    PTT.lastPolledMouse=nil
    PTT.state=PTT.recognizer and "READY" or "UNAVAILABLE"
end
function PTT.onKey(key)
    local bound=PTT.getKey()
    -- Mouse bindings are handled via Mouse.isButtonDown, not key events.
    if physicalKey(bound) and key==bound then PTT.press(key) end
end
function PTT.tick()
    local bound=PTT.getKey()
    local button=mouseButton(bound)
    if button~=nil then
        if PTT.lastPolledMouse~=bound then
            PTT.mouseWasDown=false
            PTT.lastPolledMouse=bound
        end
        if Mouse and Mouse.isButtonDown then
            local ok,down=pcall(function() return Mouse.isButtonDown(button) end)
            if ok and type(down)=="boolean" then
                if down and not PTT.mouseWasDown then PTT.press(bound) end
                if not down and PTT.mouseWasDown and PTT.active then
                    PTT.release()
                end
                PTT.mouseWasDown=down
            end
        end
        return
    end
    PTT.mouseWasDown=false
    PTT.lastPolledMouse=nil
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
