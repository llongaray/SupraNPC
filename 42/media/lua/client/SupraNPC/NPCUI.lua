-- SupraNPC - painel lateral e exame medico dedicado por NPC.
-- Nenhuma chamada ao ISHealthPanel vanilla: nao tratar NPC como segundo player.
require("ISUI/ISPanel")
require("ISUI/ISButton")
require("ISUI/ISContextMenu")
local Core = require("SupraNPC/Constants")
local Adapter = require("SupraNPC/SpawnAdapter")
local Health = require("SupraNPC/Health")
local Controller = require("SupraNPC/NPCController")
local HUD = { roster = nil, rosterPanel = nil, healthPanel = nil }

local function mouseX() return type(getMouseX) == "function" and getMouseX() or 250 end
local function mouseY() return type(getMouseY) == "function" and getMouseY() or 250 end
local function clamp01(n)
    if type(n) ~= "number" then return 0 end
    return math.max(0, math.min(1, n))
end
local function profileById(id)
    if HUD.roster and HUD.roster.profiles then
        for _, p in ipairs(HUD.roster.profiles) do
            if p.id == id then return p end
        end
    end
    return nil
end

local Details = ISPanel:derive("SupraNPCDetails")
function Details:new(id)
    local x, y, w, h = 256, 100, 365, 344
    local o = ISPanel:new(x, y, w, h)
    setmetatable(o, self)
    self.__index = self
    o.id = id
    o.backgroundColor = {r=0.06,g=0.07,b=0.08,a=0.95}
    o.borderColor = {r=0.25,g=0.62,b=0.3,a=1}
    o.moveWithMouse = true
    o.counter, o.cached = 0, nil
    return o
end
function Details:initialise() ISPanel.initialise(self) end
function Details:createChildren()
    ISPanel.createChildren(self)
    local button = ISButton:new(self.width-35, 8, 27, 25, "X", self, self.onClose)
    button:initialise()
    button:instantiate()
    self:addChild(button)
end
function Details:onClose()
    self:removeFromUIManager()
    if HUD.healthPanel == self then HUD.healthPanel = nil end
end
function Details:render()
    ISPanel.render(self)
    self.counter = self.counter + 1
    if self.counter % 35 == 1 or not self.cached then
        self.cached = Health.inspect(Adapter.get(self.id), profileById(self.id))
    end
    local result = self.cached
    local white, green = {r=0.92,g=0.92,b=0.92}, {r=0.31,g=0.88,b=0.35}
    self:drawText("SUPRANPC | AVALIACAO MEDICA", 13, 11, green.r,green.g,green.b,1,UIFont.Small)
    self:drawText(result.name, 14, 49,1,1,1,1,UIFont.Medium)
    local healthText = result.health and
        (tostring(math.floor(result.health+0.5)) .. "%") or "Indisponivel"
    self:drawText("Saude geral: " .. healthText, 14, 79,1,1,1,1,UIFont.Small)
    self:drawRect(14, 103, 320, 13, 0.9, 0.20, 0.21, 0.24)
    if result.health then
        local frac = clamp01(result.health/100)
        local r = frac < 0.4 and 0.92 or 0.25
        local g = frac < 0.4 and 0.27 or 0.8
        self:drawRect(14,103,320*frac,13,0.95,r,g,0.35)
    end
    if not result.available then
        self:drawText(result.reason or "Dados indisponiveis", 14,137,1,0.65,0.45,1,UIFont.Small)
        return
    end
    local function pct(n)
        if n == nil then return "N/D" end
        return tostring(math.floor(n * 100 + 0.5)) .. "%"
    end
    self:drawText("Dor: " .. (result.pain and tostring(math.floor(result.pain+0.5)) or "N/D") ..
        "    Fome: " .. pct(result.hunger), 14,135,1,1,1,1,UIFont.Small)
    self:drawText("Sede: " .. pct(result.thirst) ..
        "    Energia: " .. pct(result.endurance),14,158,1,1,1,1,UIFont.Small)
    self:drawText("Ferimentos visiveis: " .. tostring(#result.injuries) ..
        (result.bleeding and "  | SANGRANDO" or ""),14,189,
        result.bleeding and 1 or 0.8, result.bleeding and 0.25 or 0.9,0.3,1,UIFont.Small)
    local row = 216
    if #result.injuries == 0 then
        self:drawText("Nenhuma lesao detectada",14,row,0.75,0.85,0.75,1,UIFont.Small)
    else
        for i = 1, math.min(#result.injuries,4) do
            local injury = result.injuries[i]
            self:drawText(injury.part .. " - " .. injury.signs,14,row,1,0.83,0.7,1,UIFont.Small)
            row = row + 22
        end
        if #result.injuries > 4 then
            self:drawText("+" .. (#result.injuries-4) .. " outras lesoes",14,row,0.8,0.8,0.8,1,UIFont.Small)
        end
    end
    self:drawText("Somente consulta | sem tratamento automatico",14,320,
        white.r*0.7,white.g*0.7,white.b*0.7,1,UIFont.Small)
end

function HUD.showHealth(id)
    if HUD.healthPanel then HUD.healthPanel:removeFromUIManager() end
    local panel = Details:new(id)
    panel:initialise()
    panel:instantiate()
    panel:addToUIManager()
    panel:bringToTop()
    HUD.healthPanel = panel
end

local function dispatch(id, cmd, option)
    local player = getSpecificPlayer and getSpecificPlayer(0) or nil
    local ok, reason
    if cmd == "STANCE" then
        ok, reason = Controller.stance(id, option)
    else
        ok, reason = Controller.order(id, cmd, player, option)
    end
    if not ok then
        Core.log("COMANDO " .. tostring(id) .. " falhou: " .. tostring(reason))
    end
end

function HUD.openMenu(id)
    if not profileById(id) or not ISContextMenu then return end
    local m = ISContextMenu.get(0, mouseX(), mouseY())
    m:addOption("Analisar vida / saude", nil, function() HUD.showHealth(id) end)
    local orderOption = m:addOption("Ordens", nil, nil)
    local orders = ISContextMenu:getNew(m)
    m:addSubMenu(orderOption, orders)
    orders:addOption("Seguir o jogador (experimental)", nil,
        function() dispatch(id, "FOLLOW") end)
    orders:addOption("Aguardar aqui", nil, function() dispatch(id, "IDLE") end)
    orders:addOption("Guardar esta posicao", nil,
        function() dispatch(id, "GUARD", "NPC") end)
    orders:addOption("Guardar ponto do jogador", nil,
        function() dispatch(id, "GUARD", "PLAYER") end)

    local stanceOption = m:addOption("Postura", nil, nil)
    local stances = ISContextMenu:getNew(m)
    m:addSubMenu(stanceOption, stances)
    stances:addOption("Passiva", nil, function() dispatch(id, "STANCE", "PASSIVE") end)
    stances:addOption("Defensiva", nil, function() dispatch(id, "STANCE", "DEFENSIVE") end)
    stances:addOption("Agressiva", nil, function() dispatch(id, "STANCE", "AGGRESSIVE") end)
    local note = m:addOption("Postura so registra preferencia; combate pendente",nil,nil)
    note.notAvailable = true
end

local Sidebar = ISPanel:derive("SupraNPCSidebar")
function Sidebar:new(roster)
    local count = #roster.profiles
    local o = ISPanel:new(74, 160, 208, 41 + count * 59)
    setmetatable(o, self)
    self.__index = self
    o.roster = roster
    o.backgroundColor = {r=0.055,g=0.065,b=0.08,a=0.84}
    o.borderColor = {r=0.25,g=0.45,b=0.3,a=0.9}
    o.moveWithMouse = true
    return o
end
function Sidebar:initialise() ISPanel.initialise(self) end
function Sidebar:createChildren()
    ISPanel.createChildren(self)
    for i,profile in ipairs(self.roster.profiles) do
        local y = 33 + (i-1)*59
        local healthButton = ISButton:new(8,y,151,31,
            profile.firstName .. " " .. profile.lastName,self,self.onHealth)
        healthButton.npcId = profile.id
        healthButton:initialise()
        healthButton:instantiate()
        self:addChild(healthButton)

        local menuButton = ISButton:new(163,y,35,31,">",self,self.onMenu)
        menuButton.npcId = profile.id
        menuButton:initialise()
        menuButton:instantiate()
        self:addChild(menuButton)
    end
end
function Sidebar:onHealth(button) HUD.showHealth(button.npcId) end
function Sidebar:onMenu(button) HUD.openMenu(button.npcId) end
function Sidebar:render()
    ISPanel.render(self)
    self:drawText("SUPRANPC - EQUIPE", 9, 8,0.4,0.9,0.45,1,UIFont.Small)
    for i,profile in ipairs(self.roster.profiles) do
        local hp = Health.inspect(Adapter.get(profile.id), profile)
        local y = 67 + (i-1)*59
        local frac = hp.health and clamp01(hp.health / 100) or 0
        self:drawRect(9,y,190,8,0.86,0.18,0.18,0.19)
        if hp.health then
            self:drawRect(9,y,190*frac,8,0.96,
                frac < 0.4 and 0.9 or 0.2,
                frac < 0.4 and 0.25 or 0.78,0.3)
        end
        local entry = Controller.get(profile.id)
        local order = entry and entry.state.requested or "OFFLINE"
        self:drawText(order,9,y+10,0.7,0.78,0.75,1,UIFont.Small)
        self:drawText(hp.health and (math.floor(hp.health) .. "%") or "?",
            167,y+10,0.7,0.78,0.75,1,UIFont.Small)
    end
end

function HUD.ensure(roster)
    if not Core.isSolo() or not roster or not roster.profiles or
       #roster.profiles == 0 then return end
    if HUD.rosterPanel and HUD.roster == roster then return end
    HUD.close()
    HUD.roster = roster
    local panel = Sidebar:new(roster)
    panel:initialise()
    panel:instantiate()
    panel:addToUIManager()
    HUD.rosterPanel = panel
    Core.log("HUD de equipe iniciado para " .. #roster.profiles .. " NPC(s)")
end

function HUD.close()
    if HUD.rosterPanel then HUD.rosterPanel:removeFromUIManager() end
    if HUD.healthPanel then HUD.healthPanel:removeFromUIManager() end
    HUD.rosterPanel, HUD.healthPanel, HUD.roster = nil,nil,nil
end

return HUD
