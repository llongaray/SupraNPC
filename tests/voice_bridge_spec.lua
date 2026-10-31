package.path="42/media/lua/client/?.lua;42/media/lua/shared/?.lua;"..package.path
local Core=require("SupraNPC/Constants")
Core.isSolo=function() return true end
local files={}
getFileReader=function(path)
 local val=files[path]
 if not val then return nil end
 return {readLine=function() return val end,close=function() end}
end
getFileWriter=function(path)
 local output=""
 return {
    writeln=function(_,text) output=text end,
    close=function() files[path]=output end
 }
end
getCore=function()
 return {getKey=function() return 56 end}
end
keyBinding={}
Events={
 OnTick={Add=function() end},
 OnKeyStartPressed={Add=function() end},
 OnKeyReleased={Add=function() end},
 OnGameBoot={Add=function() end}
}
local H=require("SupraNPC/VoiceHotkey")
local B=require("SupraNPC/VoiceBridge")
local handled=nil
H.setHandler(function(text) handled=text;return true end)
assert(H.recognizer==nil)
files[B.STATUS]="READY|1"
for i=1,15 do B.update() end
assert(H.recognizer~=nil and H.state=="READY")
assert(H.press(56))
assert(files[B.COMMAND]=="START|1")
assert(H.release())
assert(files[B.COMMAND]=="STOP|1")
assert(H.state=="PROCESSING")
files[B.RESPONSE]="TRANSCRIPT|1|Yong, me segue"
for i=1,15 do B.update() end
assert(handled=="Yong, me segue")
assert(H.state=="READY" and B.pending==nil)
-- Invalid or stale transcript must not cause a new command.
files[B.RESPONSE]="TRANSCRIPT|1|Yong, fique"
for i=1,15 do B.update() end
assert(handled=="Yong, me segue")
-- New session ignores old reply even when counter overlaps.
files[B.RESPONSE]="TRANSCRIPT|2|Yong, postura agressiva"
assert(H.press(56))
assert(files[B.COMMAND]=="START|2")
for i=1,15 do B.update() end
assert(handled=="Yong, me segue")
assert(H.release())
files[B.RESPONSE]="TRANSCRIPT|2|Todos, me sigam"
for i=1,15 do B.update() end
assert(handled=="Todos, me sigam")
-- Service heartbeat stops; never claim microphone is available.
for i=1,180 do B.update() end
assert(H.recognizer==nil)
print("[SupraNPC] voice_bridge_spec: OK")
