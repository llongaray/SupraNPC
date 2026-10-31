-- Teste da renderizacao manual em IsoPlayer fora do slot do jogador.
package.path="42/media/lua/client/?.lua;42/media/lua/shared/?.lua;"..package.path
local Core=require("SupraNPC/Constants")
local Adapter=require("SupraNPC/SpawnAdapter")
local added = nil
Events={RenderOpaqueObjectsInWorld={Add=function(fn) added=fn end}}
PerformanceSettings={fboRenderChunk=true}
FBORenderCutaways=nil
Core.isSolo=function() return true end
Core.EXPERIMENTAL_SPAWN=true

local rendered=0
local actor={
    isDead=function() return false end,
    getX=function() return 101 end,
    getY=function() return 101 end,
    getZ=function() return 0 end,
    isOnScreen=function() return true end,
    getCurrentSquare=function()
        return {getLightInfo=function() return {r=1,g=1,b=1} end}
    end,
    render=function() rendered=rendered+1 end
}
getCell=function()
    return {
        getObjectList=function()
            return {contains=function(_,obj) return obj==actor end}
        end
    }
end
Adapter.clear()
Adapter.attach("supranpc_1",actor)
local Renderer=require("SupraNPC/Renderer")
assert(type(added)=="function")
Renderer.update(0)
assert(rendered==1 and Renderer.calls==1)
Core.EXPERIMENTAL_SPAWN=false
Renderer.update(0)
assert(rendered==1)
Core.EXPERIMENTAL_SPAWN=true
actor.render=function() error("render error") end
Renderer.update(0)
assert(Renderer.failed==true)
local before=Renderer.calls
Renderer.update(0)
assert(Renderer.calls==before)
print("[SupraNPC] render manual B42 e fail-closed: OK")
