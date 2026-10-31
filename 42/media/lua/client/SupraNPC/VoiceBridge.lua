-- Local STT bridge via the game's allowed Lua cache files.
-- Companion program is separate because PZ Lua cannot record microphone.
-- No sockets, executable launch, arbitrary paths or player input hooks.
local Core=require("SupraNPC/Constants")
local Hotkey=require("SupraNPC/VoiceHotkey")
local B={
    COMMAND="SupraNPC_voice_request.txt",
    RESPONSE="SupraNPC_voice_result.txt",
    STATUS="SupraNPC_voice_status.txt",
    seq=0, pending=nil, lastResult="", tickCount=0, heartbeat=nil,
    heartbeatAt=0, callback=nil
}
local provider={}
local function read(name)
    if type(getFileReader)~="function" then return nil end
    local ok,content=pcall(function()
        local f=getFileReader(name,false)
        if not f then return nil end
        local line=f:readLine()
        f:close()
        return line
    end)
    return ok and content or nil
end
local function write(name,text)
    if type(getFileWriter)~="function" then return false end
    local ok=pcall(function()
        local f=assert(getFileWriter(name,true,false))
        f:writeln(text)
        f:close()
    end)
    return ok
end
function provider:start(callback)
    if type(callback)~="function" or B.tickCount-B.heartbeatAt>150 then
        return false,"Companion STT desconectado"
    end
    B.seq=B.seq+1
    B.pending=B.seq
    -- Ignore a stale transcript from a previous game session.
    B.lastResult=read(B.RESPONSE) or ""
    B.callback=callback
    if not write(B.COMMAND,"START|"..B.pending) then
        B.pending=nil;B.callback=nil
        return false,"Nao foi possivel escrever comando STT"
    end
    return true
end
function provider:stop()
    if not B.pending then return false end
    return write(B.COMMAND,"STOP|"..B.pending)
end
function B.update()
    B.tickCount=B.tickCount+1
    if B.tickCount%15~=0 then return end
    local status=read(B.STATUS)
    local heartbeat=status and status:match("^READY|([0-9]+)$")
    if heartbeat and heartbeat~=B.heartbeat then
        B.heartbeat=heartbeat
        B.heartbeatAt=B.tickCount
    end
    local live=B.tickCount-B.heartbeatAt<=150 and
        B.heartbeat~=nil
    if live and Hotkey.recognizer~=provider then
        Hotkey.installRecognizer(provider)
        Core.log("VOICE-BRIDGE: companion online")
    elseif not live and Hotkey.recognizer==provider and
           not Hotkey.active and Hotkey.state~="PROCESSING" then
        Hotkey.installRecognizer(nil)
        Core.log("VOICE-BRIDGE: companion offline")
    end
    if B.pending then
        local line=read(B.RESPONSE)
        local kind,id,payload=line and
            line:match("^(%u+)|(%d+)|(.+)$")
        if id and tonumber(id)==B.pending and line~=B.lastResult then
            B.lastResult=line
            local callback=B.callback
            B.callback=nil
            B.pending=nil
            if callback then
                if kind=="TRANSCRIPT" then
                    callback(payload)
                else
                    Core.log("VOICE-BRIDGE: "..tostring(payload))
                    callback("")
                end
            end
        end
    end
end
if Events and Events.OnTick then Events.OnTick.Add(B.update) end
Core.VoiceBridge=B
return B
