-- Isolate the primary local player from extra IsoPlayer NPCs.
-- Never block NPC locomotion (setIgnoreMovement/setBlockMovement would also
-- block timed AI actions). Only block *manual* keyboard, aiming and joypad.
local Core=require("SupraNPC/Constants")
local I={owner=nil}
local function call(obj,name,...)
 if not obj then return nil end
 local args={...}
 local ok,res=pcall(function()
   if obj[name] then return obj[name](obj,unpack(args)) end
 end)
 if ok then return res end
end
local function isNPC(a)
 local md=call(a,"getModData")
 return md and md.SupraNPC_IsNPC==true
end
function I.remember(player)
 if not player or isNPC(player) then return false end
 I.owner=player
 return true
end
function I.getOwner(candidate)
 if I.owner and not isNPC(I.owner) then return I.owner end
 if candidate and not isNPC(candidate) then
    I.owner=candidate
    return candidate
 end
 return nil
end
function I.isolate(actor,id)
 if not actor or not id then return false end
 local md=call(actor,"getModData")
 if not md or md.SupraNPC_IsNPC~=true or md.SupraNPC_ID~=id then
    return false
 end
 -- Input component settings don't prevent independent TimedAction walking.
 call(actor,"setIgnoreInputsForDirection",true)
 call(actor,"setIgnoreAimingInput",true)
 call(actor,"setIgnoreContextKey",true)
 call(actor,"setJoypadBind",-1)
 -- Don't setIgnoreMovement(true): it blocks the NPC's scripted movement.
 Core.log("NPC_INPUT isolated "..id..
    " local="..tostring(call(actor,"isLocalPlayer"))..
    " index="..tostring(call(actor,"getPlayerIndex")))
 return true
end
function I.restoreOwner(candidate)
 local owner=I.getOwner(candidate)
 if not owner then return false end
 if IsoPlayer then
    -- Static Java methods use dot syntax; do NOT pass IsoPlayer as self.
    local active,local0=nil,nil
    if IsoPlayer.getInstance then
        local ok,res=pcall(function() return IsoPlayer.getInstance() end)
        if ok then active=res end
    end
    if IsoPlayer.getPlayer then
        local ok,res=pcall(function() return IsoPlayer.getPlayer(0) end)
        if ok then local0=res end
    end
    local wasHijacked=local0~=nil and local0~=owner
    if IsoPlayer.setInstance and active~=owner then
        pcall(function() IsoPlayer.setInstance(owner) end)
    end
    if IsoPlayer.setLocalPlayer and local0~=owner then
        pcall(function() IsoPlayer.setLocalPlayer(0,owner) end)
    end
    if wasHijacked and type(setPlayerMouse)=="function" then
        pcall(setPlayerMouse,owner)
    end
 end
 if IsoCamera and IsoCamera.setCameraCharacter then
    pcall(function() IsoCamera.setCameraCharacter(owner) end)
 end
 return true
end
function I.clear()
 I.owner=nil
end
return I
