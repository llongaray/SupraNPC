-- Intercepta a abertura da etapa vanilla de profissão com um seletor próprio.
-- O editor individual completo de NPCs será construído sobre esta fundação.
local Core = require("SupraNPC/Constants")
local Roster = require("SupraNPC/Roster")
require("ISUI/ISPanel")
require("ISUI/ISButton")

local TeamSetup = {}
local Picker = ISPanel:derive("SupraNPC_TeamPicker")

function Picker:new()
    local w, h = 550, 260
    local screenW = getCore():getScreenWidth()
    local screenH = getCore():getScreenHeight()
    local o = ISPanel:new((screenW - w) / 2, (screenH - h) / 2, w, h)
    setmetatable(o, self)
    self.__index = self
    o.count = 0
    o.backgroundColor = { r = 0.05, g = 0.07, b = 0.10, a = 0.97 }
    o.borderColor = { r = 0.42, g = 0.63, b = 0.83, a = 1 }
    o.moveWithMouse = false
    return o
end

function Picker:initialise()
    ISPanel.initialise(self)
end

function Picker:createChildren()
    ISPanel.createChildren(self)
    self.minus = ISButton:new(130, 115, 60, 35, "-", self, self.onClick)
    self.minus.internal = "MINUS"
    self.minus:initialise()
    self.minus:instantiate()
    self:addChild(self.minus)

    self.plus = ISButton:new(360, 115, 60, 35, "+", self, self.onClick)
    self.plus.internal = "PLUS"
    self.plus:initialise()
    self.plus:instantiate()
    self:addChild(self.plus)

    self.confirm = ISButton:new(160, 205, 230, 33, "Confirmar quantidade", self, self.onClick)
    self.confirm.internal = "CONFIRM"
    self.confirm:initialise()
    self.confirm:instantiate()
    self:addChild(self.confirm)
end

function Picker:render()
    ISPanel.render(self)
    local font = UIFont and UIFont.Medium or nil
    self:drawText("SUPRANPC - NOVA EQUIPE", 20, 18, 0.95, 0.87, 0.55, 1, font)
    self:drawText("Quantos NPCs adicionais ao jogador?", 20, 55, 1, 1, 1, 1, font)
    self:drawText(tostring(self.count), 265, 118, 1, 1, 1, 1, font)
    self:drawText("Limite inicial: " .. tostring(Core.MAX_COMPANIONS) .. " NPCs. Zero = partida solo.", 20, 158, 0.85, 0.85, 0.85, 1, UIFont.Small)
    self:drawText("Apos o jogador: crie cada NPC em sequencia.", 20, 180, 0.95, 0.75, 0.56, 1, UIFont.Small)
end

function Picker:onClick(button)
    if button.internal == "MINUS" then
        self.count = Core.clampCount(self.count - 1)
    elseif button.internal == "PLUS" then
        self.count = Core.clampCount(self.count + 1)
    elseif button.internal == "CONFIRM" then
        Core.pendingRoster = Roster.new(self.count)
        Core.log("Nova equipe definida: " .. tostring(self.count) .. " NPC(s).")
        self:removeFromUIManager()
        TeamSetup.openWindow = nil
    end
end

function TeamSetup.show()
    if not Core.isSolo() or TeamSetup.openWindow then return end
    Core.prompted = true
    local window = Picker:new()
    window:initialise()
    window:instantiate()
    window:addToUIManager()
    window:bringToTop()
    TeamSetup.openWindow = window
end

function TeamSetup.install()
    if TeamSetup.installed then return end
    -- Nunca sobrescrever a implementação vanilla se ela não estiver carregada.
    if not CharacterCreationProfession or not CharacterCreationProfession.setVisible then
        Core.log("UI de profissao indisponivel nesta build; seletor nao instalado.")
        return
    end
    local vanilla = CharacterCreationProfession.setVisible
    CharacterCreationProfession.setVisible = function(self, visible, ...)
        local result = vanilla(self, visible, ...)
        if visible and not Core.prompted and Core.isSolo() then
            local ok, err = pcall(TeamSetup.show)
            if not ok then Core.log("Falha ao abrir seletor: " .. tostring(err)) end
        end
        return result
    end
    TeamSetup.installed = true
    Core.log("Seletor de equipe ligado ao fluxo de criacao.")
end

Core.TeamSetup = TeamSetup
return TeamSetup
