package.path="42/media/lua/client/?.lua;42/media/lua/shared/?.lua;"..package.path
local Core=require("SupraNPC/Constants")
Core.isSolo=function() return true end
keyBinding={}
local shortcuts={}
getCore=function()
    return {
        getKey=function(_,id) return shortcuts[id] or 0 end,
        addKeyBinding=function(_,id,key,alt,shift,ctrl,alternate)
            assert(type(id)=="string" and type(key)=="number")
            assert(alt==0 and shift==false and ctrl==false and alternate==false)
            shortcuts[id]=key
        end
    }
end
Keyboard={getKeyName=function(key) return key==56 and "LALT" or tostring(key) end}
local pressed,released,ticked={},{},{}
Events={
    OnGameBoot={Add=function() end},
    OnKeyStartPressed={Add=function(fn) pressed[#pressed+1]=fn end},
    OnKeyReleased={Add=function(fn) released[#released+1]=fn end},
    OnTick={Add=function(fn) ticked[#ticked+1]=fn end}
}
local V=require("SupraNPC/VoiceHotkey")
assert(V.getKey()==0 and V.keyLabel()=="SEM TECLA")
assert(#keyBinding==2 and keyBinding[2].value==V.KEY_ID)
V.registerBinding()
assert(#keyBinding==2)
assert(#pressed==1 and #released==1 and #ticked==1)
-- Real regression from console(3).txt: B42 returned a synthetic code
-- 10003; Keyboard.getKeyName(10003) throws a Java exception every HUD frame.
local labelCalls=0
Keyboard.getKeyName=function(key)
    assert(key>=1 and key<=255,"native keyboard index out of bounds")
    labelCalls=labelCalls+1
    return key==56 and "LALT" or tostring(key)
end
shortcuts[V.KEY_ID]=10003
assert(V.getKey()==10003 and V.keyLabel()=="MOUSE BTN 3")
assert(V.keyLabel()=="MOUSE BTN 3" and labelCalls==0)
pressed[1](10003) -- mouse must never pass through keyboard event path
assert(not V.active)
local mouseDown=false
Mouse={isButtonDown=function(btn)
    assert(btn==3)
    return mouseDown
end}
local errors={}
V.setFeedback(function(t) errors[#errors+1]=t end)
ticked[1]()
mouseDown=true
ticked[1]()
ticked[1]()
assert(#errors==1 and errors[1]:find("STT nao integrado",1,true))
mouseDown=false
ticked[1]()
mouseDown=true
ticked[1]()
assert(#errors==2)
mouseDown=false
ticked[1]()
shortcuts[V.KEY_ID]=-1
assert(V.getKey()==0 and V.keyLabel()=="RECONFIGURAR")
shortcuts[V.KEY_ID]=256
assert(V.getKey()==0 and V.keyLabel()=="RECONFIGURAR")
shortcuts[V.KEY_ID]=55.5
assert(V.getKey()==0 and V.keyLabel()=="RECONFIGURAR")
shortcuts[V.KEY_ID]=56
assert(V.getKey()==56 and V.keyLabel()=="LALT")
assert(V.keyLabel()=="LALT" and labelCalls==1) -- per-frame label cache
local feedback={}
V.setFeedback(function(t) feedback[#feedback+1]=t end)
pressed[1](56)
assert(V.state=="UNAVAILABLE" and not V.active)
assert(feedback[1]:find("STT nao integrado",1,true))
local text=nil
V.setHandler(function(t) text=t;return true end)
local callback=nil
local stopped=0
assert(V.installRecognizer({
    start=function(_,fn) callback=fn;return true end,
    stop=function() stopped=stopped+1;return true end
}))
assert(V.state=="READY")
-- Same saved mouse binding may be used for full press/release with STT.
shortcuts[V.KEY_ID]=10003
mouseDown=true
ticked[1]()
assert(V.active and V.state=="LISTENING")
ticked[1]()
assert(V.active)
mouseDown=false
ticked[1]()
assert(not V.active and stopped==1)
V.reset()
shortcuts[V.KEY_ID]=56
pressed[1](56)
assert(V.active and V.state=="LISTENING")
assert(not V.press(56))
released[1](56)
assert(not V.active and V.state=="PROCESSING" and stopped==2)
assert(V.submitTranscript("Yong, me segue") and text=="Yong, me segue")
assert(V.state=="READY")
assert(not V.submitTranscript(""))
-- Unbound synthetic IDs other than 10000..10007 remain invalid.
shortcuts[V.KEY_ID]=10008
assert(V.getKey()==0 and V.keyLabel()=="RECONFIGURAR")
V.reset()
assert(V.state=="READY")
print("[SupraNPC] voice_hotkey_spec: OK")
