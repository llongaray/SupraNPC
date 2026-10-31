package.path="42/media/lua/shared/?.lua;"..package.path
local T=require("SupraNPC/Territory")
local n={
 {text="NPC:BASE:A",x=100,y=200,z=0},
 {text="NPC:BASE:B",x=112,y=209,z=0},
 {text="NPC:LOOT Mercado",x=130,y=212,z=0},
 {text="NPC:PERIGO Hospital",x=120,y=199,z=0},
 {text="Farmacia",x=125,y=215,z=0}
}
local data=T.import(n)
assert(data.base and data.base.defined=="RECT")
assert(data.base.x1==100 and data.base.x2==112)
assert(data.base.y1==200 and data.base.y2==209)
assert(T.inside(data,105,205,0) and not T.inside(data,130,212,0))
local goal=T.basePoint(data)
assert(goal.x==106.5 and goal.y==204.5)
assert(T.knowledge(data).LOOT==1)
assert(T.knowledge(data).DANGER==1)
assert(T.knowledge(data).NOTE==1)
assert(T.import({{text="NPC:BASE",x=4,y=5}}).base.defined=="POINT")
assert(T.import({{text="NPC:BASE:A",x=0,y=0},{text="NPC:BASE:B",x=200,y=200}}).base==nil)
assert(T.import({{text="NPC:BASE:A",x=0,y=0},{text="NPC:BASE:B",x=4,y=4,z=1}}).base==nil)
assert(T.import({{text="X",x=0/0,y=3}}).base==nil)
print("[SupraNPC] territory_spec: OK")
