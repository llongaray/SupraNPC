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
shortcuts[V.KEY_ID]=56
assert(V.keyLabel()=="LALT")
local feedback={}
V.setFeedback(function(t) feedback[#feedback+1]=t end)
pressed[1](56)
assert(V.state=="UNAVAILABLE" and not V.active)
assert(feedback[1]:find("Microfone indisponivel",1,true))
local text=nil
V.setHandler(function(t) text=t;return true end)
local callback=nil
local stopped=0
assert(V.installRecognizer({
    start=function(_,fn) callback=fn;return true end,
    stop=function() stopped=stopped+1;return true end
}))
assert(V.state=="READY")
pressed[1](56)
assert(V.active and V.state=="LISTENING")
assert(not V.press(56))
released[1](56)
assert(not V.active and V.state=="PROCESSING" and stopped==1)
assert(V.submitTranscript("Yong, me segue") and text=="Yong, me segue")
assert(V.state=="READY")
assert(not V.submitTranscript(""))
V.reset()
assert(V.state=="READY")
print("[SupraNPC] voice_hotkey_spec: OK")
