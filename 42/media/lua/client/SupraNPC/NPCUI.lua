-- SupraNPC - painel lateral e exame medico dedicado por NPC.
-- Nenhuma chamada ao ISHealthPanel vanilla: nao tratar NPC como segundo player.
require("ISUI/ISPanel")
require("ISUI/ISButton")
require("ISUI/ISTextEntryBox")
require("ISUI/ISContextMenu")
pcall(require, "ISUI/ISUI3DModel")
-- ISNewHealthPanel e o mesmo painel corporal usado pelo ISHealthPanel
-- vanilla, mas nao substituimos o painel global do jogador.
if not ISNewHealthPanel then pcall(require, "ISHealthPanel") end
local Core = require("SupraNPC/Constants")
local Adapter = require("SupraNPC/SpawnAdapter")
local Health = require("SupraNPC/Health")
local Controller = require("SupraNPC/NPCController")
local Speech = require("SupraNPC/NPCSpeech")
local VoiceCommands = require("SupraNPC/VoiceCommands")
local HUD = { roster = nil, rosterPanel = nil, healthPanel = nil,
    feedback = nil, feedbackTicks = 0 }

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
    local x, y, w, h = 300, 85, 535, 407
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
    local actor = Adapter.get(self.id)
    if actor and ISNewHealthPanel then
        local ok, native = pcall(function()
            local panel = ISNewHealthPanel:new(16,80,actor)
            panel:initialise()
            panel:instantiate()
            panel:setVisible(true)
            self:addChild(panel)
            return panel
        end)
        if ok then
            self.nativeBody = native
        else
            Core.log("UI corpo nativo indisponivel: " .. tostring(native))
        end
    end
    if actor and ISUI3DModel then
        local ok, preview = pcall(function()
            local model = ISUI3DModel:new(381,83,139,229)
            model:initialise()
            model:instantiate()
            model:setCharacter(actor)
            model:setState("idle")
            if IsoDirections then model:setDirection(IsoDirections.S) end
            model:setIsometric(false)
            self:addChild(model)
            return model
        end)
        if ok then self.model = preview else
            Core.log("UI preview medico indisponivel: " .. tostring(preview))
        end
    end
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
    self:drawText("AVALIACAO MEDICA - " .. result.name,
        15,12,1,1,1,1,UIFont.Medium)
    self:drawRect(12,47,511,1,0.5,0.6,0.6,0.6)
    if self.nativeBody then
        self:drawText("Corpo / ferimentos",16,62,0.9,0.9,0.9,1,UIFont.Small)
    else
        self:drawText("Visual corporal vanilla indisponivel",16,84,
            1,0.65,0.5,1,UIFont.Small)
    end
    if self.model then
        self:drawText("Previa 3D do NPC",384,62,0.9,0.9,0.9,1,UIFont.Small)
        self:drawRectBorder(375,80,148,239,1,0.4,0.4,0.4)
    end
    local tx=158
    local hp = result.health and tostring(math.floor(result.health+0.5)) .. "%"
        or "N/D"
    self:drawText("Saude geral: " .. hp,tx,87,1,1,1,1,UIFont.Small)
    self:drawRect(tx,115,195,12,0.9,0.25,0.25,0.25)
    if result.health then
        local frac = clamp01(result.health/100)
        self:drawRect(tx,115,195*frac,12,1,
            frac < 0.4 and 0.86 or 0.22,
            frac < 0.4 and 0.22 or 0.82,0.27)
    end
    local function fmt(v,mult)
        return type(v) == "number" and
            (tostring(math.floor(v*(mult or 1)+0.5)) ..
             (mult and "%" or "")) or "N/D"
    end
    self:drawText("Dor: " .. fmt(result.pain),tx,145,1,1,1,1,UIFont.Small)
    self:drawText("Fome: " .. fmt(result.hunger,100),tx,166,1,1,1,1,UIFont.Small)
    self:drawText("Sede: " .. fmt(result.thirst,100),tx,187,1,1,1,1,UIFont.Small)
    self:drawText("Energia: " .. fmt(result.endurance,100),tx,208,1,1,1,1,UIFont.Small)
    self:drawText("Ferimentos: " .. #result.injuries,
        tx,236,0.94,0.83,0.72,1,UIFont.Small)
    if result.bleeding then
        self:drawText("SANGRAMENTO",tx,258,1,0.3,0.3,1,UIFont.Small)
    end
    local offset=277
    for i=1,math.min(3,#result.injuries) do
        local lesion=result.injuries[i]
        self:drawText(lesion.part .. ": " .. lesion.signs,
            tx,offset,1,0.8,0.7,1,UIFont.Small)
        offset=offset+20
    end
    if not result.available then
        self:drawText(result.reason or "Sem dados da entidade",
            tx,280,1,0.65,0.4,1,UIFont.Small)
    end
    self:drawRect(12,374,511,1,0.3,0.5,0.5,0.5)
    self:drawText("Somente consulta | nao altera tratamento ou saude",
        16,381,0.76,0.76,0.76,1,UIFont.Small)
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
    local profile=profileById(id)
    Speech.playerCommand(player,profile and profile.firstName or "Companheiro",
        cmd,option,ok)
    local npc=Adapter.get(id)
    if npc then Speech.npcReply(npc,cmd,option,ok) end
    HUD.feedback = {
        id = id, text = ok and
            (cmd == "STANCE" and ("Postura: " .. tostring(option)) or
             ("Ordem: " .. tostring(cmd))) or
            ("Falha: " .. tostring(reason))
    }
    HUD.feedbackTicks = 0
    if not ok then
        Core.log("COMANDO " .. tostring(id) .. " falhou: " .. tostring(reason))
    else
        Core.log("COMANDO confirmado " .. tostring(id) ..
            " " .. tostring(cmd))
    end
end

function HUD.openMenu(id)
    if not profileById(id) or not ISContextMenu then return end
    local m = ISContextMenu.get(0, mouseX(), mouseY())
    m:addOption("Analisar vida / saude", nil, function() HUD.showHealth(id) end)
    local orderOption = m:addOption("Ordens", nil, nil)
    local orders = ISContextMenu:getNew(m)
    m:addSubMenu(orderOption, orders)
    orders:addOption("Seguir o jogador", nil,
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
    -- A postura agora influencia o raio de interceptacao (2.2/5/9 tiles).
end

function HUD.sendVoice(utterance)
    local roster=HUD.roster
    local parsed,reason=VoiceCommands.parse(utterance,
        roster and roster.profiles)
    if not parsed then
        HUD.feedback={text="Voz: "..tostring(reason)}
        HUD.feedbackTicks=0
        Core.log("VOICE rejected: "..tostring(reason))
        return false,reason
    end
    for _,id in ipairs(parsed.targets) do
        dispatch(id,parsed.cmd,parsed.option)
    end
    Core.log("VOICE command "..parsed.cmd.." targets="..#parsed.targets)
    return true
end

local Sidebar = ISPanel:derive("SupraNPCSidebar")
function Sidebar:new(roster)
    local count = #roster.profiles
    local o = ISPanel:new(74, 160, 271, 111 + count * 76)
    setmetatable(o, self)
    self.__index = self
    o.roster = roster
    o.backgroundColor = {r=0.055,g=0.065,b=0.08,a=0.84}
    o.borderColor = {r=0.25,g=0.45,b=0.3,a=0.9}
    o.moveWithMouse = true
    o.refreshCount = 0
    o.healthCache = {}
    return o
end
function Sidebar:initialise() ISPanel.initialise(self) end
function Sidebar:createChildren()
    ISPanel.createChildren(self)
    self.models = {}
    for i,profile in ipairs(self.roster.profiles) do
        local y = 33 + (i-1)*76
        local actor = Adapter.get(profile.id)
        if actor and ISUI3DModel then
            local ok, model = pcall(function()
                local preview = ISUI3DModel:new(8,y,47,60)
                preview:initialise()
                preview:instantiate()
                preview:setCharacter(actor)
                preview:setState("idle")
                if IsoDirections then preview:setDirection(IsoDirections.S) end
                preview:setIsometric(false)
                self:addChild(preview)
                return preview
            end)
            if ok then self.models[profile.id] = model else
                Core.log("Preview NPC " .. profile.id ..
                    " indisponivel: " .. tostring(model))
            end
        end
        local healthButton = ISButton:new(60,y,162,31,
            profile.firstName .. " " .. profile.lastName,self,self.onHealth)
        healthButton.npcId = profile.id
        healthButton:initialise()
        healthButton:instantiate()
        self:addChild(healthButton)

        local menuButton = ISButton:new(228,y,34,31,">",self,self.onMenu)
        menuButton.npcId = profile.id
        menuButton:initialise()
        menuButton:instantiate()
        self:addChild(menuButton)
    end
    local base=33 + #self.roster.profiles*76
    self.voiceTitle="COMANDO DE VOZ (WIN+H)"
    self.voiceEntry=ISTextEntryBox:new("",8,base+19,188,26)
    self.voiceEntry:initialise()
    self.voiceEntry:instantiate()
    local panel=self
    self.voiceEntry.onCommandEntered=function()
        panel:onVoice()
    end
    self:addChild(self.voiceEntry)
    local send=ISButton:new(202,base+19,60,26,"Enviar",self,self.onVoice)
    send:initialise()
    send:instantiate()
    self:addChild(send)
    self.voiceButton=send
end
function Sidebar:onVoice()
    if not self.voiceEntry then return end
    local utterance=self.voiceEntry:getText()
    if utterance and utterance~="" then
        HUD.sendVoice(utterance)
        self.voiceEntry:setText("")
    end
end
function Sidebar:onHealth(button) HUD.showHealth(button.npcId) end
function Sidebar:onMenu(button) HUD.openMenu(button.npcId) end
function Sidebar:render()
    ISPanel.render(self)
    self.refreshCount = self.refreshCount + 1
    if HUD.feedback then
        HUD.feedbackTicks = HUD.feedbackTicks + 1
        if HUD.feedbackTicks > 400 then HUD.feedback = nil end
    end
    self:drawText("SUPRANPC - EQUIPE", 9, 8,0.4,0.9,0.45,1,UIFont.Small)
    self:drawText(self.voiceTitle or "COMANDO DE VOZ (WIN+H)",
       9,33 + #self.roster.profiles*76,0.7,0.85,0.72,1,UIFont.Small)
    for i,profile in ipairs(self.roster.profiles) do
        if self.refreshCount % 35 == 1 or not self.healthCache[profile.id] then
            self.healthCache[profile.id] = Health.inspect(Adapter.get(profile.id), profile)
        end
        local hp = self.healthCache[profile.id]
        local y = 67 + (i-1)*76
        local frac = hp.health and clamp01(hp.health / 100) or 0
        self:drawRect(61,y,198,8,0.86,0.18,0.18,0.19)
        if hp.health then
            self:drawRect(61,y,198*frac,8,0.96,
                frac < 0.4 and 0.9 or 0.2,
                frac < 0.4 and 0.25 or 0.78,0.3)
        end
        local entry = Controller.get(profile.id)
        local order = entry and entry.state.requested or "OFFLINE"
        local runtime = entry and entry.navStatus or "OFFLINE"
        local label = order .. " / " .. runtime
        self:drawText(label,61,y+10,
            (runtime=="FAILED" or runtime=="BLOCKED") and 1 or 0.7,
            (runtime=="FAILED" or runtime=="BLOCKED") and 0.4 or 0.78,
            0.75,1,UIFont.Small)
        self:drawText(hp.health and (math.floor(hp.health) .. "%") or "?",
            226,y+10,0.7,0.78,0.75,1,UIFont.Small)
    end
    if HUD.feedback then
        local msg = HUD.feedback.text
        self:drawText(msg:sub(1,38),8,self.height-12,0.96,0.74,0.38,1,UIFont.Small)
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
    Speech.clear()
end

return HUD
